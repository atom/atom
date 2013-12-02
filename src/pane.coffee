{Model} = require 'telepath'
Focusable = require './focusable'
PaneAxis = require './pane-axis'

module.exports =
class Pane extends Model
  Focusable.includeInto(this)

  @properties
    container: null
    parent: null
    items: []
    panes: -> [this]
    activeItem: null

  # Public: Contains the active item or nothing. Used in PaneContainer::activePaneItems.
  @relatesToMany 'activeItems', ->
    @items.where(id: @$activeItem.map('id'))

  @behavior 'hasFocus', ->
    activeItemFocused =
      @$activeItem
        .flatMapLatest((item) -> item?.$hasFocus)
        .map((value) -> !!value)
    @$focused.or(activeItemFocused)

  attached: ->
    @manageFocus()
    @setActiveItem(@items.getFirst()) unless @activeItem?
    @subscribe @items.onEach (item) => item.setFocusManager?(@focusManager)
    @subscribe @$focused, 'value', (focused) => @activeItem?.setFocused?(true) if focused
    @subscribe @$hasFocus, 'value', (hasFocus) => @container?.activePane = this if hasFocus

  remove: ->
    if @parent is @container
      @items.clear()
      false
    else
      @parent.children.remove(this)

  setActiveItem: (item) ->
    item = @addItem(item) if item? and not @items.contains(item)
    hadFocus = @hasFocus
    @activeItem = item
    item.setFocused?(true) if hadFocus
    item

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
    unless @parent.orientation is orientation
      axis = new PaneAxis({orientation, @parent, children: [this]})
      @parent.children.replace(this, axis)
      @parent = axis

    pane = new Pane({@container, @parent, @focusManager, items})
    switch side
      when 'before' then @parent.children.insertBefore(this, pane)
      when 'after' then @parent.children.insertAfter(this, pane)
    pane.focused = @hasFocus
    pane

  itemForUri: (uri) ->
    @items.find({uri}) ? @items.find(-> @getUri?() is uri)
