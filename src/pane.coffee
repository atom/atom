{$, View} = require './space-pen-extensions'
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

  @deserialize: (state) ->
    new this(PaneModel.deserialize(state.model))

  @content: (wrappedView) ->
    @div class: 'pane', tabindex: -1, =>
      @div class: 'flexbox-repaint-hack', =>
        @div class: 'item-views', outlet: 'itemViews'

  @delegatesProperties 'items', 'activeItem', toProperty: 'model'
  @delegatesMethods 'getItems', 'showNextItem', 'showPreviousItem', 'getActiveItemIndex',
    'showItemAtIndex', 'showItem', 'addItem', 'itemAtIndex',  'removeItem', 'removeItemAtIndex',
    'moveItem', 'moveItemToPane', 'destroyItem', 'destroyItems', 'destroyActiveItem',
    'destroyInactiveItems', 'saveActiveItem', 'saveActiveItemAs', 'saveItem', 'saveItemAs',
    'saveItems', 'itemForUri', 'showItemForUri', 'promptToSaveItem', 'copyActiveItem',
    toProperty: 'model'

  previousActiveItem: null

  # Private:
  initialize: (args...) ->
    if args[0] instanceof PaneModel
      @model = args[0]
    else
      @model = new PaneModel(items: args)
      @model._view = this

    @onItemAdded(item) for item in @items
    @viewsByItem = new WeakMap()
    @handleEvents()

  hasFocus: ->
    @is(':focus') or @is(':has(:focus)')

  handleEvents: ->
    @subscribe @model.$activeItem, 'value', @onActiveItemChanged
    @subscribe @model, 'item-added', @onItemAdded
    @subscribe @model, 'item-removed', @onItemRemoved
    @subscribe @model, 'item-moved', @onItemMoved
    @subscribe @model, 'before-item-destroyed', @onBeforeItemDestroyed
    @subscribe @model, 'item-destroyed', @onItemDestroyed

    @subscribe @model.$focused, 'value', (focused) =>
      if focused
        @focus() unless @hasFocus()
      else
        @blur() if @hasFocus()

    @subscribe this, 'focus', =>
      @model.suppressBlur => @activeView?.focus()
      false

    @subscribe this, 'focusin', =>
      @makeActive()
      @model.focus()

    @subscribe this, 'focusout', (e) => @model.blur()

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

  # Private:
  afterAttach: (onDom) ->
    @focus() if @model.focused and onDom

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
    if isFocused
      @model.suppressBlur -> view.focus()
    @activeView = view
    @trigger 'pane:active-item-changed', [item]

  onItemAdded: (item, index) =>
    if typeof item.on is 'function'
      @subscribe item, 'destroyed', => @destroyItem(item)
    @trigger 'pane:item-added', [item, index]

  onItemRemoved: (item, index, detach) =>
    @cleanupItemView(item, detach)
    @trigger 'pane:item-removed', [item, index]

  onItemMoved: (item, newIndex) =>
    @trigger 'pane:item-moved', [item, newIndex]

  onBeforeItemDestroyed: (item) =>
    @unsubscribe(item) if typeof item.off is 'function'
    @trigger 'pane:before-item-destroyed', [item]

  onItemDestroyed: (item) =>
    @getContainer()?.itemDestroyed(item)

  # Private:
  activeItemTitleChanged: =>
    @trigger 'pane:active-item-title-changed'

  # Private:
  cleanupItemView: (item, detach) ->
    if item instanceof $
      viewToRemove = item
    else if viewToRemove = @viewsByItem.get(item)
      @viewsByItem.delete(item)

    if @items.length > 0
      if detach and item is viewToRemove
        viewToRemove?.detach()
      else if detach and viewToRemove?.setModel
        viewToRemove.setModel(null) # dont want to destroy the model, so set to null
        viewToRemove.remove()
      else
        viewToRemove?.remove()
    else
      if detach and item is viewToRemove
        viewToRemove?.detach()
      else if detach and viewToRemove?.setModel
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

  splitLeft: (items...) -> @model.splitLeft({items})._view

  splitRight: (items...) -> @model.splitRight({items})._view

  splitUp: (items...) -> @model.splitUp({items})._view

  splitDown: (items...) -> @model.splitDown({items})._view

  # Private:
  getContainer: ->
    @closest('.panes').view()

  # Private:
  remove: (selector, keepData) ->
    return super if keepData

    @unsubscribe()
    @model.destroy() unless @model.isDestroyed()

    if @isActive()
      @getContainer().makeNextPaneActive()

    super
