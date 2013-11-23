{Model} = require 'telepath'
PaneAxis = require './pane-axis'

module.exports =
class Pane extends Model
  @properties
    container: null
    items: []
    activeItemId: null
    widthPercent: 100
    heightPercent: 100

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
    wasEmpty = @items.isEmpty()
    item = @items.insert(@getActiveItemIndex() + 1, item)
    @setActiveItem(item) if wasEmpty
    item

  addItems: (items) ->
    wasEmpty = @items.isEmpty()
    items = @items.insertArray(@getActiveItemIndex() + 1, items)
    @setActiveItem(@items.getFirst()) if wasEmpty
    items

  moveItem: (item, newIndex) ->
    oldIndex = @items.indexOf(item)
    throw new Error("Can't move non-existent item") if oldIndex is -1
    @items.insert(newIndex, item)
    @items.splice(oldIndex, 1)

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

  splitLeft: (items...) ->
    @split('horizontal', 'before', items)

  splitRight: (items...) ->
    @split('horizontal', 'after', items)

  splitUp: (items...) ->
    @split('vertical', 'before', items)

  splitDown: (items...) ->
    @split('vertical', 'after', items)

  split: (orientation, side, items) ->
    unless @container.orientation is orientation
      axis = new PaneAxis({orientation, @container, children: [this]})
      @container.children.replace(this, axis)
      @container = axis

    pane = new Pane({@container, items})
    switch side
      when 'before' then @container.children.insertBefore(this, pane)
      when 'after' then @container.children.insertAfter(this, pane)
