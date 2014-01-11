{$, View} = require './space-pen-extensions'
Serializable = require 'serializable'
Delegator = require 'delegato'

PaneModel = require './pane-model'

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
      @div class: 'item-views', =>
        @div class: 'flexbox-repaint-hack', outlet: 'itemViews'

  @delegatesProperties 'items', 'activeItem', toProperty: 'model'
  @delegatesMethods 'getItems', 'showNextItem', 'showPreviousItem', 'getActiveItemIndex',
    'showItemAtIndex', 'showItem', 'addItem', 'itemAtIndex',  'removeItem', 'removeItemAtIndex',
    'moveItem', 'moveItemToPane', 'destroyItem', 'destroyItems', 'destroyActiveItem',
    'destroyInactiveItems', 'saveActiveItem', 'saveActiveItemAs', 'saveItem', 'saveItemAs',
    'saveItems', 'itemForUri', 'showItemForUri', 'promptToSaveItem', 'copyActiveItem',
    'isActive', 'makeActive', toProperty: 'model'

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

  handleEvents: ->
    @subscribe @model, 'destroyed', => @remove()

    @subscribe @model.$activeItem, 'value', @onActiveItemChanged
    @subscribe @model, 'item-added', @onItemAdded
    @subscribe @model, 'item-removed', @onItemRemoved
    @subscribe @model, 'item-moved', @onItemMoved
    @subscribe @model, 'before-item-destroyed', @onBeforeItemDestroyed
    @subscribe @model, 'item-destroyed', @onItemDestroyed
    @subscribe @model.$active, 'value', @onActiveStatusChanged

    @subscribe this, 'focusin', => @model.focus()
    @subscribe this, 'focusout', => @model.blur()
    @subscribe this, 'focus', =>
      @activeView?.focus()
      false

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

  onActiveStatusChanged: (active) =>
    if active
      @addClass('active')
      @trigger 'pane:became-active'
    else
      @removeClass('active')
      @trigger 'pane:became-inactive'

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
    @trigger 'pane:item-added', [item, index]

  onItemRemoved: (item, index, destroyed) =>
    if item instanceof $
      viewToRemove = item
    else if viewToRemove = @viewsByItem.get(item)
      @viewsByItem.delete(item)

    removingLastItem = @model.items.length is 0
    hasFocus = @hasFocus()

    @getContainer().focusNextPane() if hasFocus and removingLastItem

    if viewToRemove?
      viewToRemove.setModel?(null)
      if destroyed
        viewToRemove.remove()
      else
        viewToRemove.detach()

    # @focus() if hasFocus and not removingLastItem

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

  beforeRemove: ->
    @getContainer()?.focusNextPane() if @hasFocus()
    @model.destroy() unless @model.isDestroyed()

  # Private:
  remove: (selector, keepData) ->
    return super if keepData
    @unsubscribe()
    super
