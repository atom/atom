_ = require 'underscore'
guid = require 'guid'

module.exports =
class WsChannel
  _.extend @prototype, require('event-emitter')

  constructor: (@name) ->
    @clientId = guid.create().toString()
    @socket = new WebSocket('ws://localhost:8080')
    @socket.onopen = =>
      @rawSend 'subscribe', @name, @clientId
      @trigger 'channel:opened'

    @socket.onmessage = (message) =>
      [operation, data] = JSON.parse(message.data)
      @trigger(data...)

  send: (data...) ->
    @rawSend('broadcast', data)

  rawSend: (args...) ->
    @socket.send(JSON.stringify(args))
