_ = require 'underscore'

MediaConnection = require './media-connection'

module.exports =
class Participant
  _.extend(@prototype, require 'event-emitter')

  constructor: (@channel, @state, @sessionClientId) ->
    {@clientId} = @state
    @mediaConnection = new MediaConnection(this)

  getState: -> @state

  send: (data...) -> @channel.send(@clientId, data...)

  getMediaConnection: -> @mediaConnection

  isEqual: (other) ->
    if other instanceof @constructor
      otherState = other.getState()
    else
      otherState = other
    _.isEqual(@getState(), otherState)

  isSelf: -> @clientId is @sessionClientId
