_ = require 'underscore'
{createPeer, connectDocument} = require './session-utils'

module.exports =
class SharingSession
  _.extend @prototype, require('event-emitter')

  peer: null
  sharing: false

  start: ->
    return if @peer

    @peer = createPeer()
    @peer.on 'connection', (connection) ->
      connection.on 'open', ->
        console.log 'sending document'
        windowState = atom.getWindowState()
        connection.send(windowState.serialize())
        connectDocument(windowState, connection)

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
