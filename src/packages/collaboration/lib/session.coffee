_ = require 'underscore'
guid = require 'guid'
keytar = require 'keytar'
patrick = require 'patrick'
{Site} = require 'telepath'

Project = require 'project'
WsChannel = require './ws-channel'
Participant = require './participant'
{getSessionUrl} = require './session-utils'

module.exports =
class Session
  _.extend @prototype, require('event-emitter')

  constructor: ({@site, @id, @host, @port, @secure}) ->
    @nextOutgoingEventId = 1
    @lastEventIdsBySite = {}

    @secure ?= config.get('collaboration.secure') ? true
    @host ?= config.get('collaboration.host') ? 'fallout.in'
    @participants = []
    @listening = false

    if @site?
      @leader = true
      @id = guid.create().toString()
      @nextGuestSiteId = @site.id + 1
    else
      @leader = false

  isLeader: -> @leader

  isListening: -> @listening

  start: ->
    @channel = @subscribe(@id)

    @channel.on 'channel:closed', =>
      @listening = false
      @trigger 'stopped'

    @channel.on 'channel:participant-entered', (participantState) =>
      @trigger 'participant-entered', @addParticipant(participantState)

    @channel.on 'channel:participant-exited', (participantState) =>
      @trigger 'participant-exited', @removeParticipant(participantState)

    @channel.on 'channel:direct-message', (senderId, data...) =>
      @participantForClientId(senderId)?.trigger(data...)

    if @isLeader()
      @doc = @createDocument()

      @getClientIdToSiteIdMap().set(@clientId, @site.id)

      @connectDocument()
      @channel.one 'channel:subscribed', (participantStates) =>
        @setParticipantStates(participantStates)
        @listening = true
        @trigger 'started', @getParticipants()

      @on 'participant-entered', (participant) =>
        # inject siteId; TODO: should be moved to somewhere less sketch
        guestSiteId = @nextGuestSiteId++
        clientIdToSiteId = @getClientIdToSiteIdMap()
        clientIdToSiteId.set(participant.clientId, guestSiteId)

        @snapshotRepository (repoSnapshot) =>
          welcomePackage =
            siteId: guestSiteId
            doc: @doc.serialize()
            repoSnapshot: repoSnapshot
          @channel.broadcast 'welcome', welcomePackage

    else
      @channel.one 'channel:subscribed', (participantStates) =>
        @setParticipantStates(participantStates)
        @channel.one 'welcome', ({doc, siteId, repoSnapshot}) =>
          @site = new Site(siteId)
          @doc = @site.deserializeDocument(doc)
          @connectDocument()

          repoUrl = @doc.get('collaborationState.repositoryState.url')
          @mirrorRepository repoUrl, repoSnapshot, =>
            @sendMediaConnectionOffers()
            @trigger 'started', @getParticipants()

  copySessionId: ->
    pasteboard.write(getSessionUrl(@id)) if @id

  createDocument: ->
    @site.createDocument
      windowState: atom.windowState
      collaborationState:
        guest: {description: '', candidate: '', ready: false}
        host: {description: '', candidate: ''}
        clientIdToSiteId: {}
        repositoryState:
          url: project.getRepo().getConfigValue('remote.origin.url')
          branch: project.getRepo().getShortHead()

  stop: -> @channel.stop()

  getSite: -> @site

  getDocument: -> @doc

  getId: -> @id

  participantForClientId: (targetClientId) ->
    _.find @getParticipants(), ({clientId}) -> clientId is targetClientId

  getParticipants: -> _.clone(@participants)

  getOtherParticipants: ->
    @getParticipants().filter ({clientId}) => clientId isnt @clientId

  addParticipant: (participantState) ->
    participant = new Participant(@channel, participantState)
    @participants.push(participant)
    participant.getMediaConnection().waitForOffer()
    participant

  removeParticipant: (participantState) ->
    clientIdToRemove = participantState.clientId
    participant = _.find @participants, ({clientId}) -> clientId is clientIdToRemove
    @participants = _.without(@participants, participant)
    participant

  setParticipantStates: (participantStates) ->
    @participants = participantStates.map (state) => new Participant(@channel, state)

  sendMediaConnectionOffers: ->
    for participant in @getOtherParticipants()
      participant.getMediaConnection().sendOffer()

  # TODO: move this functionality into the Participant Object
  getClientIdToSiteIdMap: -> @doc.get('collaborationState.clientIdToSiteId')

  subscribe: (name) ->
    token = keytar.getPassword('github.com', 'github')
    channel = new WsChannel({name, @host, @port, @secure, token})
    {@clientId} = channel
    channel

  verifyEvent: (event) ->
    {site, id} = event
    lastId = @lastEventIdsBySite[site]
    if lastId? and id isnt lastId + 1
      console.error("Expected next event to be #{lastId + 1} but got #{id} for site #{site}")
    @lastEventIdsBySite[site] = id

  stampEvent: (event) ->
    event.id = @nextOutgoingEventId++
    event.site = window.site.id

  connectDocument:  ->
    @doc.on 'replicate-change', (event) =>
      @stampEvent(event)
      @channel.broadcast('document-changed', event)

    @channel.on 'document-changed', (event) =>
      @verifyEvent(event)
      @doc.applyRemoteChange(event)

  snapshotRepository: (callback) ->
    patrick.snapshot project.getPath(), (error, repoSnapshot) =>
      if error
        console.error(error)
      else
        callback(repoSnapshot)

  mirrorRepository: (repoUrl, repoSnapshot, callback) ->
    repoPath = Project.pathForRepositoryUrl(repoUrl)

    progressCallback = (args...) => @trigger 'mirror-progress', args...

    patrick.mirror repoPath, repoSnapshot, {progressCallback}, (error) =>
      if error?
        console.error(error)
      else
        callback()
