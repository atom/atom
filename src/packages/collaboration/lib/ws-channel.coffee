_ = require 'underscore'
guid = require 'guid'

module.exports =
class WsChannel
  _.extend @prototype, require('event-emitter')

  constructor: ({@name, host, port, token}) ->
    host ?= 'localhost'
    port ?= 8080
    @clientId = guid.create().toString()
    @socket = new WebSocket("ws://#{host}:#{port}?token=#{token}")
    @socket.onopen = =>
      @rawSend 'subscribe', @name, @clientId

    @socket.onclose = =>
      @trigger 'channel:closed'

    @socket.onmessage = (message) =>
      data = JSON.parse(message.data)
      @trigger(data...)

  stop: ->
    @socket.close()

  send: (data...) ->
    @rawSend('broadcast', data)

  rawSend: (args...) ->
    @socket.send(JSON.stringify(args))
