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
    item = @addItem(item) if item? and not @items.contains(item)
    @activeItemId = item?.id

  getActiveItemIndex: ->
    @items.indexOf(@activeItem)

  addItem: (item) ->
    item = @items.insert(@getActiveItemIndex() + 1, item)
    @setActiveItem(item) if @items.length is 1
    item

  moveItem: (item, index) ->
    @items.insert(index, item)

  removeItem: (item) ->
    index = @items.indexOf(item)
    unless index is -1
      if item is @activeItem
        if item is @items.getLast()
          @setActiveItem(@getPreviousItem(item))
        else
          @setActiveItem(@getNextItem(item))
      @items.splice(index, 1)

  removeItems: ->
    @items.splice(0, @items.length)

  getNextItem: (item) ->
    return unless @items.length > 1

    index = @items.indexOf(item)
    unless index is -1
      @items.get((index + 1) % @items.length)

  getPreviousItem: (item) ->
    return unless @items.length > 1

    index = @items.indexOf(item)
    unless index is -1
      index = @items.length if index is 0
      @items.get(index - 1)
