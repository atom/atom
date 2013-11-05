{Model} = require 'telepath'

module.exports =
class Pane extends Model
  @properties
    items: []
    activeItemId: null

  @relatesToOne 'activeItem', ->
    @items.where(id: @$activeItemId)

  attached: ->
    @setActiveItem(@items.getFirst()) unless @activeItem?

  setActiveItem: (item) ->
    @activeItemId = item.id
