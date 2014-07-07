_ = require 'underscore-plus'
{Subscriber, Emitter} = require 'emissary'

idCounter = 0
nextId = -> idCounter++

module.exports =
class Decoration
  Emitter.includeInto(this)

  @isType: (decorationParams, type) ->
    if _.isArray(decorationParams.type)
      type in decorationParams.type
    else
      type is decorationParams.type

  constructor: (@marker, @displayBuffer, @params) ->
    @id = nextId()
    @params.id = @id
    @flashQueue = null

  destroy: ->
    @displayBuffer.removeDecoration(this)
    @emit 'destoryed'

  update: (newParams) ->
    # TODO: implement

  getParams: ->
    @params

  isType: (type) ->
    Decoration.isType(@params, type)

  matchesPattern: (decorationPattern) ->
    return false unless decorationPattern?
    for key, value of decorationPattern
      return false if @params[key] != value
    true

  flash: (klass, duration=500) ->
    flashObject = {class: klass, duration}
    @flashQueue ?= []
    @flashQueue.push(flashObject)
    @emit 'flash'

  consumeNextFlash: ->
    return @flashQueue.shift() if @flashQueue?.length > 0
    null
