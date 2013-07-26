_ = require 'underscore'
guid = require 'guid'
keytar = require 'keytar'
patrick = require 'patrick'
{Site} = require 'telepath'

MediaConnection = require './media-connection'
Project = require 'project'
WsChannel = require './ws-channel'

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

    @channel.on 'channel:participant-entered', (participant) =>
      @participants.push(participant)
      @trigger 'participant-entered', participant

    @channel.on 'channel:participant-exited', (participant) =>
      @participants = @participants.filter ({clientId}) ->
        clientId isnt participant.clientId
      @trigger 'participant-exited', participant

    if @isLeader()
      @doc = @createDocument()
      @mediaConnection = @createMediaConnection()
      @mediaConnection.start()

      @connectDocument()
      @channel.one 'channel:subscribed', (@participants) =>
        @listening = true
        @trigger 'started', @getParticipants()

      @on 'participant-entered', =>
        @snapshotRepository (repoSnapshot) =>
          welcomePackage =
            siteId: @nextGuestSiteId++
            doc: @doc.serialize()
            repoSnapshot: repoSnapshot
          @channel.send 'welcome', welcomePackage

    else
      @channel.one 'channel:subscribed', (@participants) =>
        @channel.one 'welcome', ({doc, siteId, repoSnapshot}) =>
          @site = new Site(siteId)
          @doc = @site.deserializeDocument(doc)
          @connectDocument()
          @mediaConnection = @createMediaConnection()
          @mediaConnection.start()

          repoUrl = @doc.get('collaborationState.repositoryState.url')
          @mirrorRepository repoUrl, repoSnapshot, =>
            @trigger 'started', @getParticipants()

  createMediaConnection: ->
    guest = @doc.get('collaborationState.guest')
    host = @doc.get('collaborationState.host')
    if @isLeader()
      new MediaConnection(guest, host, isLeader: true)
    else
      new MediaConnection(host, guest)

  waitForStream: (callback) ->
    @mediaConnection.waitForStream callback

  createDocument: ->
    @site.createDocument
      windowState: atom.windowState
      collaborationState:
        guest: {description: '', candidate: '', ready: false}
        host: {description: '', candidate: ''}
        repositoryState:
          url: project.getRepo().getConfigValue('remote.origin.url')
          branch: project.getRepo().getShortHead()

  stop: -> @channel.stop()

  getSite: -> @site

  getDocument: -> @doc

  getId: -> @id

  getParticipants: -> _.clone(@participants)

  getOtherParticipants: ->
    @getParticipants().filter ({clientId}) => clientId isnt @clientId

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
      @channel.send('document-changed', event)

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
