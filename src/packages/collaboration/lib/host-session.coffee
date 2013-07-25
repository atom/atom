fs = require 'fs'

_ = require 'underscore'
guid = require 'guid'
patrick = require 'patrick'
telepath = require 'telepath'

MediaConnection = require './media-connection'
sessionUtils = require './session-utils'
Session = require './session'

module.exports =
class HostSession extends Session
  participants: null
  peer: null
  mediaConnection: null
  doc: null

  constructor: (@site) ->
    @id = guid.create().toString()
    @nextGuestSiteId = @site.id + 1

  getSite: -> @site

  getDocument: -> @doc

  createDocument: ->
    @site.createDocument
      windowState: atom.windowState
      collaborationState:
        guest: {description: '', candidate: '', ready: false}
        host: {description: '', candidate: ''}
        participants: []
        repositoryState:
          url: project.getRepo().getConfigValue('remote.origin.url')
          branch: project.getRepo().getShortHead()

  start: ->
    return if @isSharing()

    @doc = @createDocument()
    channel = @subscribe("presence-atom")
    channel.on 'channel:opened', =>
      @trigger 'started'
      @connectDocument(@doc, channel)

    channel.on 'channel:participant-joined', =>
      @snapshotRepository (repoSnapshot) =>
        welcomePackage =
          siteId: @nextGuestSiteId++
          doc: @doc.serialize()
          repoSnapshot: repoSnapshot
        channel.send 'client-welcome', welcomePackage

    # host = @doc.get('collaborationState.host')
    # guest = @doc.get('collaborationState.guest')
    # @mediaConnection = new MediaConnection(host, guest, isHost: true)
    # @mediaConnection.start()
    @getId()

  snapshotRepository: (callback) ->
    patrick.snapshot project.getPath(), (error, repoSnapshot) =>
      if error
        console.error(error)
      else
        callback(repoSnapshot)

      # @participants = @doc.get('collaborationState.participants')
      # @participants.push
      #   id: @getId()
      #   email: project.getRepo().getConfigValue('user.email')
      #
      # @participants.on 'changed', =>
      #   @trigger 'participants-changed', @participants.toObject()

      # connection.on 'close', =>
      #   @participants.each (participant, index) =>
      #     if connection.peer is participant.get('id')
      #       @participants.remove(index)
      #   @trigger 'stopped'

  stop: ->
    return unless @peer?
    @peer.destroy()
    @peer = null

  waitForStream: (callback) ->
    @mediaConnection.waitForStream callback

  getId: -> @id

  isSharing: ->
    @peer? and not _.isEmpty(@peer.connections)
