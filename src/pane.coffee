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

  created: ->
    console.log "Pane::created"
    @manageFocus()
    @activateItem(@items.getFirst()) unless @activeItem?
    @subscribe @items.onEach (item) => item.setFocusManager?(@focusManager)
    @subscribe @$focused, 'value', (focused) => @activeItem?.setFocused?(true) if focused
    @subscribe @$hasFocus, 'value', (hasFocus) => @container?.activePane = this if hasFocus

  # Deprecated: Use ::items property directly instead
  getItems: -> @items.getValues()

  remove: ->
    if @parent is @container
      @items.clear()
      false
    else
      @parent.children.remove(this)

  activateItem: (item) ->
    item = @addItem(item) if item? and not @items.contains(item)
    hadFocus = @hasFocus
    @activeItem = item
    item.setFocused?(true) if hadFocus
    item

  getActiveItemIndex: ->
    @items.indexOf(@activeItem)

  addItem: (item, index=@getActiveItemIndex() + 1) ->
    wasEmpty = @items.isEmpty()
    item = @items.insert(index, item)
    @activateItem(item) if wasEmpty
    item

  addItems: (items) ->
    wasEmpty = @items.isEmpty()
    items = @items.insertArray(@getActiveItemIndex() + 1, items)
    @activateItem(@items.getFirst()) if wasEmpty
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
          @activateItem(@getPreviousItem(item))
        else
          @activateItem(@getNextItem(item))
      @items.splice(index, 1)

  removeItems: ->
    @items.splice(0, @items.length)

  moveItemToPane: (item, pane, index) ->
    pane.addItem(item, index)
    @removeItem(item)

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

  splitLeft: (params) ->
    @split('horizontal', 'before', params)

  splitRight: (params) ->
    @split('horizontal', 'after', params)

  splitUp: (params) ->
    @split('vertical', 'before', params)

  splitDown: (params) ->
    @split('vertical', 'after', params)

  split: (orientation, side, params={}) ->
    unless @parent.orientation is orientation
      axis = new PaneAxis({orientation, @parent, children: [this]})
      @parent.children.replace(this, axis)
      @parent = axis

    {items, copyActiveItem, moveActiveItem} = params
    items ?= []

    if copyActiveItem
      if itemCopy = @activeItem?.copy?()
        items.unshift(itemCopy)
      else
        moveActiveItem = true

    pane = new Pane({@container, @parent, @focusManager, items})
    switch side
      when 'before' then @parent.children.insertBefore(this, pane)
      when 'after' then @parent.children.insertAfter(this, pane)

    if moveActiveItem and @activeItem?
      console.log "move active item"
      @moveItemToPane(@activeItem, pane, 0)

    pane.focused = @hasFocus
    pane

  itemForUri: (uri) ->
    @items.find({uri}) ? @items.find(-> @getUri?() is uri)
