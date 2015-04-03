Grim = require 'grim'
if Grim.includeDeprecatedAPIs
  module.exports = require('theorist').Model
  return

PropertyAccessors = require 'property-accessors'

nextInstanceId = 1

module.exports =
class Model
  PropertyAccessors.includeInto(this)

  @resetNextInstanceId: -> nextInstanceId = 1

  alive: true

  constructor: (params) ->
    @assignId(params?.id)

  assignId: (id) ->
    @id ?= id ? nextInstanceId++

  @::advisedAccessor 'id',
    set: (id) -> nextInstanceId = id + 1 if id >= nextInstanceId

  destroy: ->
    return unless @isAlive()
    @alive = false
    @destroyed?()

  isAlive: -> @alive

  isDestroyed: -> not @isAlive()
