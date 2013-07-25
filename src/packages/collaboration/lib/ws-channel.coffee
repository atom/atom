_ = require 'underscore'
guid = require 'guid'
keytar = require 'keytar'

module.exports =
class WsChannel
  _.extend @prototype, require('event-emitter')

  constructor: (@name) ->
    @clientId = guid.create().toString()
    token = keytar.getPassword('github.com', 'github')
    @socket = new WebSocket("ws://localhost:8080?token=#{token}")
    @socket.onopen = =>
      @rawSend 'subscribe', @name, @clientId

    @socket.onmessage = (message) =>
      data = JSON.parse(message.data)
      @trigger(data...)

  send: (data...) ->
    @rawSend('broadcast', data)

  rawSend: (args...) ->
    @socket.send(JSON.stringify(args))
