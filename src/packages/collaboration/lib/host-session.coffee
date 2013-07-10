_ = require 'underscore'
telepath = require 'telepath'
{createPeer, connectDocument} = require './session-utils'

module.exports =
class HostSession
  _.extend @prototype, require('event-emitter')

  doc: null
  participants: null
  peer: null
  sharing: false

  start: ->
    return if @peer?

    @peer = createPeer()
    @doc = telepath.Document.create({}, site: telepath.createSite(@getId()))
    @doc.set('windowState', atom.windowState)
    @doc.set('participants', [])
    @participants = @doc.get('participants')
    @participants.push
      id: @getId()
      email: git.getConfigValue('user.email')
    @participants.observe =>
      @trigger 'participants-changed', @participants.toObject()

    @peer.on 'connection', (connection) =>
      console.log connection
      connection.on 'open', =>
        console.log 'sending document'
        connection.send(@doc.serialize())
        connectDocument(@doc, connection)

      connection.on 'close', =>
        console.log 'conection closed'
        @participants.each (participant, index) =>
          if connection.peer is participant.get('id')
            @participants.remove(index)

    @peer.on 'open', =>
      console.log 'sharing session started'
      @sharing = true
      @trigger 'started'

    @peer.on 'close', =>
      console.log 'sharing session stopped'
      @sharing = false
      @trigger 'stopped'

    @getId()

  stop: ->
    return unless @peer?

    @peer.destroy()
    @peer = null

  getId: ->
    @peer.id

  isSharing: ->
    @sharing
