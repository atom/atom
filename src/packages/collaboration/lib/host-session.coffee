fs = require 'fs'

_ = require 'underscore'
patrick = require 'patrick'
telepath = require 'telepath'

MediaConnection = require './media-connection'
sessionUtils = require './session-utils'

module.exports =
class HostSession
  _.extend @prototype, require('event-emitter')

  participants: null
  peer: null
  mediaConnection: null
  doc: null
  sharing: false

  constructor: ->
    @doc = site.createDocument
      windowState: atom.windowState
      collaborationState:
        guest: {description: '', candidate: '', ready: false}
        host: {description: '', candidate: ''}
        participants: []
        repositoryState:
          url: git.getConfigValue('remote.origin.url')
          branch: git.getShortHead()

    host = @doc.get('collaborationState.host')
    guest = @doc.get('collaborationState.guest')
    @mediaConnection = new MediaConnection(host, guest, isHost: true)

    @peer = sessionUtils.createPeer()

  start: ->
    return if @isSharing()

    @mediaConnection.start()
    patrick.snapshot project.getPath(), (error, repoSnapshot) =>
      throw new Error(error) if error

      @participants = @doc.get('collaborationState.participants')
      @participants.push
        id: @getId()
        email: git.getConfigValue('user.email')

      @participants.on 'changed', =>
        @trigger 'participants-changed', @participants.toObject()

      @peer.on 'connection', (connection) =>
        connection.on 'open', =>
          @sharing = true
          connection.send({repoSnapshot, doc: @doc.serialize()})
          sessionUtils.connectDocument(@doc, connection)
          @trigger 'started'

        connection.on 'close', =>
          @sharing = false
          @participants.each (participant, index) =>
            if connection.peer is participant.get('id')
              @participants.remove(index)
          @trigger 'stopped'

    @getId()

  stop: ->
    return unless @peer?
    @peer.destroy()
    @peer = null

  waitForStream: (callback) ->
    @mediaConnection.waitForStream callback

  getId: ->
    @peer.id

  isSharing: ->
    @sharing
