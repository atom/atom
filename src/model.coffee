nextInstanceId = 1

module.exports =
class Model
  @resetNextInstanceId: -> nextInstanceId = 1

  alive: true

  constructor: (params) ->
    @assignId(params?.id)

  assignId: (id) ->
    @id ?= id ? nextInstanceId++
    nextInstanceId = id + 1 if id >= nextInstanceId

  destroy: ->
    return unless @isAlive()
    @alive = false
    @destroyed?()

  isAlive: -> @alive

  isDestroyed: -> not @isAlive()
