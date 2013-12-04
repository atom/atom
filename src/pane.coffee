{dirname} = require 'path'
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
    if hadFocus
      @activeItem.setFocused?(true) ? @setFocused(true)
    item

  activateNextItem: ->
    nextItemIndex = (@getActiveItemIndex() + 1) % @items.length
    @activateItem(@items.get(nextItemIndex))

  activatePreviousItem: ->
    previousItemIndex = @getActiveItemIndex() - 1
    previousItemIndex = @items.length - 1 if previousItemIndex < 0
    @activateItem(@items.get(previousItemIndex))

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

  # Public: Prompt the user to save the given item.
  promptToSaveItem: (item) ->
    return true unless item.shouldPromptToSave?()

    uri = item.getUri?() ? item.uri
    chosen = atom.confirm
      message: "'#{item.getTitle?() ? uri}' has changes, do you want to save them?"
      detailedMessage: "Your changes will be lost if you close this item without saving."
      buttons: ["Save", "Cancel", "Don't Save"]

    console.log "CHOSEN", chosen

    switch chosen
      when 0 then @saveItem(item, -> true)
      when 1 then false
      when 2 then true

    # Public: Saves the currently focused item.
  saveActiveItem: =>
    @saveItem(@activeItem)

  # Public: Save and prompt for path for the currently focused item.
  saveActiveItemAs: =>
    @saveItemAs(@activeItem)

  # Public: Saves the specified item and call the next action when complete.
  saveItem: (item, nextAction) ->
    if item.getUri?() ? item.uri
      item.save?()
      nextAction?()
    else
      @saveItemAs(item, nextAction)

  # Public: Prompts for path and then saves the specified item. Upon completion
  # it also calls the next action.
  saveItemAs: (item, nextAction) ->
    return unless item.saveAs?

    itemPath = item.getPath?() ? item.path
    itemPath = dirname(itemPath) if itemPath
    path = atom.showSaveDialogSync(itemPath)
    if path
      item.saveAs(path)
      nextAction?()

  # Public: Saves all items in this pane.
  saveItems: =>
    @saveItem(item) for item in @items
