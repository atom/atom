{find, compact} = require 'underscore-plus'
{Model} = require 'theorist'
Serializable = require 'serializable'

module.exports =
class PaneModel extends Model
  Serializable.includeInto(this)

  @properties
    activeItem: null

  constructor: ({@items, @activeItem}) ->
    @items ?= []
    @activeItem ?= @items[0]

  serializeParams: ->
    items: compact(@items.map((item) -> item.serialize?()))
    activeItemUri: @activeItem?.getUri?()

  deserializeParams: (params) ->
    {items, activeItemUri} = params
    params.items = items.map (itemState) -> atom.deserializers.deserialize(itemState)
    params.activeItem = find params.items, (item) -> item.getUri?() is activeItemUri
    params
