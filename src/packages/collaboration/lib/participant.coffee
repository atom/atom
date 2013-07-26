_ = require 'underscore'

module.exports =
class Participant
  constructor: (@state) ->
    {@clientId} = @state

  getState: -> @state

  isEqual: (other) ->
    if other instanceof @constructor
      otherState = other.getState()
    else
      otherState = other
    _.isEqual(@getState(), otherState)
