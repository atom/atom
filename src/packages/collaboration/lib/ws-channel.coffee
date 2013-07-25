_ = require 'underscore'
guid = require 'guid'
keytar = require 'keytar'

module.exports =
class WsChannel
  _.extend @prototype, require('event-emitter')

  constructor: ({@name, @port}) ->
    @port ?= 8080
    @clientId = guid.create().toString()
    token = keytar.getPassword('github.com', 'github')
    @socket = new WebSocket("ws://localhost:#{@port}?token=#{token}")
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
