_ = require 'underscore'
guid = require 'guid'
keytar = require 'keytar'
patrick = require 'patrick'
{Site} = require 'telepath'

Project = require 'project'
WsChannel = require './ws-channel'

module.exports =
class Session
  _.extend @prototype, require('event-emitter')

  constructor: ({@site, @id}) ->
    if @site?
      @id = guid.create().toString()
      @leader = true
      @nextGuestSiteId = @site.id + 1
    else
      @leader = false

  isLeader: -> @leader

  start: ->
    @channel = @subscribe(@id)

    @channel.on 'channel:closed', => @trigger 'stopped'

    @channel.on 'channel:participant-exited', (participant) =>
      @trigger 'participant-exited', participant

    @channel.on 'channel:participant-entered', (participant) =>
      @trigger 'participant-entered', participant

      if @isLeader()
        @snapshotRepository (repoSnapshot) =>
          welcomePackage =
            siteId: @nextGuestSiteId++
            doc: @doc.serialize()
            repoSnapshot: repoSnapshot
          @channel.send 'welcome', welcomePackage

    if @isLeader()
      @doc = @createDocument()
      @connectDocument()
      @channel.one 'channel:subscribed', (participants) =>
        @trigger 'started', participants
    else
      @channel.one 'channel:subscribed', (participants) =>
        @channel.one 'welcome', ({doc, siteId, repoSnapshot}) =>
          @site = new Site(siteId)
          @doc = @site.deserializeDocument(doc)
          @connectDocument()
          repoUrl = @doc.get('collaborationState.repositoryState.url')
          @mirrorRepository repoUrl, repoSnapshot, =>
            @trigger 'started', participants

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

  subscribe: (channelName) ->
    channel = new WsChannel(channelName)
    {@clientId} = channel
    channel

  connectDocument:  ->
    @doc.on 'replicate-change', (event) =>
      @channel.send('document-changed', event)

    @channel.on 'document-changed', (event) =>
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
