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
    unless @items.contains(item)
      item = @items.insert(@getActiveItemIndex() + 1, item)
    @activeItemId = item?.id

  getActiveItemIndex: ->
    @items.indexOf(@activeItem)
