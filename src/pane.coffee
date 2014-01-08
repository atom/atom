{dirname} = require 'path'
{$, View} = require './space-pen-extensions'
_ = require 'underscore-plus'
Serializable = require 'serializable'
Delegator = require 'delegato'

PaneModel = require './pane-model'
PaneRow = require './pane-row'
PaneColumn = require './pane-column'

# Public: A container which can contains multiple items to be switched between.
#
# Items can be almost anything however most commonly they're {EditorView}s.
#
# Most packages won't need to use this class, unless you're interested in
# building a package that deals with switching between panes or tiems.
module.exports =
class Pane extends View
  Serializable.includeInto(this)
  Delegator.includeInto(this)

  @version: 1

  @content: (wrappedView) ->
    @div class: 'pane', tabindex: -1, =>
      @div class: 'item-views', outlet: 'itemViews'

  @delegatesProperties 'items', 'activeItem', toProperty: 'model'
  @delegatesMethods 'getItems', 'showNextItem', 'showPreviousItem', 'getActiveItemIndex',
    'showItemAtIndex', 'showItem', 'addItem', 'itemAtIndex', toProperty: 'model'

  previousActiveItem: null

  # Private:
  initialize: (args...) ->
    if args[0]?.model?
      {@model, @focusOnAttach} = args[0]
    else
      @model = new PaneModel(items: args)

    @onItemAdded(item) for item in @items
    @viewsByItem = new WeakMap()
    @handleEvents()

  handleEvents: ->
    @subscribe @model.$activeItem, 'value', @onActiveItemChanged
    @subscribe @model, 'item-added', @onItemAdded

    @subscribe this, 'focus', => @activeView?.focus(); false
    @subscribe this, 'focusin', => @makeActive()

    @command 'pane:save-items', => @saveItems()
    @command 'pane:show-next-item', => @showNextItem()
    @command 'pane:show-previous-item', => @showPreviousItem()

    @command 'pane:show-item-1', => @showItemAtIndex(0)
    @command 'pane:show-item-2', => @showItemAtIndex(1)
    @command 'pane:show-item-3', => @showItemAtIndex(2)
    @command 'pane:show-item-4', => @showItemAtIndex(3)
    @command 'pane:show-item-5', => @showItemAtIndex(4)
    @command 'pane:show-item-6', => @showItemAtIndex(5)
    @command 'pane:show-item-7', => @showItemAtIndex(6)
    @command 'pane:show-item-8', => @showItemAtIndex(7)
    @command 'pane:show-item-9', => @showItemAtIndex(8)

    @command 'pane:split-left', => @splitLeft(@copyActiveItem())
    @command 'pane:split-right', => @splitRight(@copyActiveItem())
    @command 'pane:split-up', => @splitUp(@copyActiveItem())
    @command 'pane:split-down', => @splitDown(@copyActiveItem())
    @command 'pane:close', => @destroyItems()
    @command 'pane:close-other-items', => @destroyInactiveItems()

  deserializeParams: (params) ->
    params.model = PaneModel.deserialize(params.model)
    params

  serializeParams: ->
    model: @model.serialize()
    focusOnAttach: @is(':has(:focus)')

  # Private:
  afterAttach: (onDom) ->
    if @focusOnAttach and onDom
      @focusOnAttach = null
      @focus()

    return if @attached
    @attached = true
    @trigger 'pane:attached', [this]

  # Public: Focus this pane.
  makeActive: ->
    wasActive = @isActive()
    for pane in @getContainer().getPanes() when pane isnt this
      pane.makeInactive()
    @addClass('active')
    @trigger 'pane:became-active' unless wasActive

  # Public: Unfocus this pane.
  makeInactive: ->
    wasActive = @isActive()
    @removeClass('active')
    @trigger 'pane:became-inactive' if wasActive

  # Public: Returns whether this pane is currently focused.
  isActive: ->
    @getContainer()?.getActivePane() == this

  # Public: Returns the next pane, ordered by creation.
  getNextPane: ->
    panes = @getContainer()?.getPanes()
    return unless panes.length > 1
    nextIndex = (panes.indexOf(this) + 1) % panes.length
    panes[nextIndex]

  getActivePaneItem: ->
    @activeItem

  onActiveItemChanged: (item) =>
    @previousActiveItem?.off? 'title-changed', @activeItemTitleChanged
    @previousActiveItem = item

    return unless item?

    isFocused = @is(':has(:focus)')
    item.on? 'title-changed', @activeItemTitleChanged
    view = @viewForItem(item)
    @itemViews.children().not(view).hide()
    @itemViews.append(view) unless view.parent().is(@itemViews)
    view.show() if @attached
    view.focus() if isFocused
    @activeView = view
    @trigger 'pane:active-item-changed', [item]

  onItemAdded: (item, index) =>
    if typeof item.on is 'function'
      @subscribe item, 'destroyed', => @destroyItem(item)
    @trigger 'pane:item-added', [item, index]

  # Private:
  activeItemTitleChanged: =>
    @trigger 'pane:active-item-title-changed'

  # Public: Remove the currently active item.
  destroyActiveItem: =>
    @destroyItem(@activeItem)
    false

  # Public: Remove the specified item.
  destroyItem: (item, options) ->
    @unsubscribe(item) if _.isFunction(item.off)
    @trigger 'pane:before-item-destroyed', [item]

    if @promptToSaveItem(item)
      @getContainer()?.itemDestroyed(item)
      @removeItem(item, options)
      item.destroy?()
      true
    else
      false

  # Public: Remove and delete all items.
  destroyItems: ->
    @destroyItem(item) for item in @getItems()

  # Public: Remove and delete all but the currently focused item.
  destroyInactiveItems: ->
    @destroyItem(item) for item in @getItems() when item isnt @activeItem

  # Public: Prompt the user to save the given item.
  promptToSaveItem: (item) ->
    return true unless item.shouldPromptToSave?()

    uri = item.getUri()
    chosen = atom.confirm
      message: "'#{item.getTitle?() ? item.getUri()}' has changes, do you want to save them?"
      detailedMessage: "Your changes will be lost if you close this item without saving."
      buttons: ["Save", "Cancel", "Don't Save"]

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
    if item.getUri?()
      item.save?()
      nextAction?()
    else
      @saveItemAs(item, nextAction)

  # Public: Prompts for path and then saves the specified item. Upon completion
  # it also calls the next action.
  saveItemAs: (item, nextAction) ->
    return unless item.saveAs?

    itemPath = item.getPath?()
    itemPath = dirname(itemPath) if itemPath
    path = atom.showSaveDialogSync(itemPath)
    if path
      item.saveAs(path)
      nextAction?()

  # Public: Saves all items in this pane.
  saveItems: =>
    @saveItem(item) for item in @getItems()

  # Public:
  removeItem: (item) ->
    index = @items.indexOf(item)
    @removeItemAtIndex(index) if index >= 0

  # Public: Just remove the item at the given index.
  removeItemAtIndex: (index) ->
    item = @items[index]
    @activeItem.off? 'title-changed', @activeItemTitleChanged if item is @activeItem
    @showNextItem() if item is @activeItem and @items.length > 1
    _.remove(@items, item)
    @cleanupItemView(item)
    @trigger 'pane:item-removed', [item, index]

  # Public: Moves the given item to a the new index.
  moveItem: (item, newIndex) ->
    oldIndex = @items.indexOf(item)
    @items.splice(oldIndex, 1)
    @items.splice(newIndex, 0, item)
    @trigger 'pane:item-moved', [item, newIndex]

  # Public: Moves the given item to another pane.
  moveItemToPane: (item, pane, index) ->
    @isMovingItem = true
    pane.addItem(item, index)
    @removeItem(item)
    @isMovingItem = false

  # Public: Finds the first item that matches the given uri.
  itemForUri: (uri) ->
    _.detect @items, (item) -> item.getUri?() is uri

  # Public: Focuses the first item that matches the given uri.
  showItemForUri: (uri) ->
    if item = @itemForUri(uri)
      @showItem(item)
      true
    else
      false

  # Private:
  cleanupItemView: (item) ->
    if item instanceof $
      viewToRemove = item
    else if viewToRemove = @viewsByItem.get(item)
      @viewsByItem.delete(item)

    if @items.length > 0
      if @isMovingItem and item is viewToRemove
        viewToRemove?.detach()
      else if @isMovingItem and viewToRemove?.setModel
        viewToRemove.setModel(null) # dont want to destroy the model, so set to null
        viewToRemove.remove()
      else
        viewToRemove?.remove()
    else
      if @isMovingItem and item is viewToRemove
        viewToRemove?.detach()
      else if @isMovingItem and viewToRemove?.setModel
        viewToRemove.setModel(null) # dont want to destroy the model, so set to null

      @parent().view().removeChild(this)

  # Private:
  viewForItem: (item) ->
    if item instanceof $
      item
    else if view = @viewsByItem.get(item)
      view
    else
      viewClass = item.getViewClass()
      view = new viewClass(item)
      @viewsByItem.set(item, view)
      view

  # Private:
  viewForActiveItem: ->
    @viewForItem(@activeItem)

  # Private:
  adjustDimensions: -> # do nothing

  # Private:
  horizontalGridUnits: -> 1

  # Private:
  verticalGridUnits: -> 1

  # Public: Creates a new pane above with a copy of the currently focused item.
  splitUp: (items...) ->
    @split(items, 'column', 'before')

  # Public: Creates a new pane below with a copy of the currently focused item.
  splitDown: (items...) ->
    @split(items, 'column', 'after')

  # Public: Creates a new pane left with a copy of the currently focused item.
  splitLeft: (items...) ->
    @split(items, 'row', 'before')

  # Public: Creates a new pane right with a copy of the currently focused item.
  splitRight: (items...) ->
    @split(items, 'row', 'after')

  # Private:
  split: (items, axis, side) ->
    PaneContainer = require './pane-container'

    parent = @parent().view()
    unless parent.hasClass(axis)
      axis = @buildPaneAxis(axis)
      if parent instanceof PaneContainer
        @detach()
        axis.addChild(this)
        parent.setRoot(axis)
      else
        parent.insertChildBefore(this, axis)
        axis.addChild(this)
      parent = axis

    newPane = new Pane(items...)

    switch side
      when 'before' then parent.insertChildBefore(this, newPane)
      when 'after' then parent.insertChildAfter(this, newPane)
    @getContainer().adjustPaneDimensions()
    newPane.makeActive()
    newPane.focus()
    newPane

  # Private:
  buildPaneAxis: (axis) ->
    switch axis
      when 'row' then new PaneRow()
      when 'column' then new PaneColumn()

  # Private:
  getContainer: ->
    @closest('.panes').view()

  # Private:
  copyActiveItem: ->
    @activeItem.copy?() ? atom.deserializers.deserialize(@activeItem.serialize())

  # Private:
  remove: (selector, keepData) ->
    return super if keepData
    @parent().view().removeChild(this)

  # Private:
  beforeRemove: ->
    if @is(':has(:focus)')
      @getContainer().focusNextPane() or atom.workspaceView?.focus()
    else if @isActive()
      @getContainer().makeNextPaneActive()

    item.destroy?() for item in @getItems()
