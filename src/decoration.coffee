_ = require 'underscore-plus'
{Subscriber, Emitter} = require 'emissary'

idCounter = 0
nextId = -> idCounter++

module.exports =
class Decoration
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  @isType: (decorationParams, type) ->
    if _.isArray(decorationParams.type)
      type in decorationParams.type
    else
      type is decorationParams.type

  constructor: (@marker, @params) ->
    @id = nextId()
    @params.id = @id

  getParams: ->
    @params

  isType: (type) ->
    Decoration.isType(@params, type)

  matchesPattern: (decorationPattern) ->
    return false unless decorationPattern?
    for key, value of decorationPattern
      return false if @params[key] != value
    true
