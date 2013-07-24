_ = require 'underscore'
redis = require 'redis'
guid = require 'guid'

module.exports =
class RedisChannel
  _.extend @prototype, require('event-emitter')

  constructor: (@name) ->
    @clientId = guid.create().toString()

    @subscribeClient = redis.createClient()
    @sendClient = redis.createClient()
    @subscribeClient.on 'error', (error) -> console.error("Error on subscribe client", error)
    @sendClient.on 'error', (error) -> console.error("Error on send client", error)

    @subscribeClient.subscribe @name, =>
      console.log "subscribed to channel", @name
      @send 'channel:participant-joined', @clientId
      @trigger 'channel:opened'

    @subscribeClient.on 'message', (channelName, message) =>
      return unless channelName is @name
      [senderId, eventName, args...] = JSON.parse(message)
      unless senderId is @clientId
        console.log "message on channel", eventName, args...
        @trigger(eventName, args...)

  send: (eventName, args...) ->
    message = JSON.stringify([@clientId, eventName, args...])
    @sendClient.publish(@name, message)
