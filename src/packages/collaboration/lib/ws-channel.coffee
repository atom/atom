_ = require 'underscore'
guid = require 'guid'

module.exports =
class WsChannel
  _.extend @prototype, require('event-emitter')

  constructor: (@name) ->
    @clientId = guid.create().toString()
    @socket = new WebSocket('ws://localhost:8080')
    @socket.onopen = =>
      console.log "opened"
      @rawSend 'subscribe', @name
      @send 'channel:participant-joined', @clientId
      @trigger 'channel:opened'

    @socket.onmessage = (message) =>
      console.log "received", message.data
      [operation, data] = JSON.parse(message.data)
      @trigger(data...)

  send: (data...) ->
    @rawSend('broadcast', data)

  rawSend: (args...) ->
    console.log "sending", args
    @socket.send(JSON.stringify(args))
