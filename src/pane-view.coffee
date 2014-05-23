{$, View} = require './space-pen-extensions'
Delegator = require 'delegato'
{deprecate} = require 'grim'
PropertyAccessors = require 'property-accessors'

Pane = require './pane'

# Public: A container which can contains multiple items to be switched between.
#
# Items can be almost anything however most commonly they're {EditorView}s.
#
# Most packages won't need to use this class, unless you're interested in
# building a package that deals with switching between panes or items.
module.exports =
class PaneView extends View
  Delegator.includeInto(this)
  PropertyAccessors.includeInto(this)

  @version: 1

  @content: (wrappedView) ->
    @div class: 'pane', tabindex: -1, =>
      @div class: 'item-views', outlet: 'itemViews'

  @delegatesProperties 'items', 'activeItem', toProperty: 'model'
  @delegatesMethods 'getItems', 'activateNextItem', 'activatePreviousItem', 'getActiveItemIndex',
    'activateItemAtIndex', 'activateItem', 'addItem', 'itemAtIndex', 'moveItem', 'moveItemToPane',
    'destroyItem', 'destroyItems', 'destroyActiveItem', 'destroyInactiveItems',
    'saveActiveItem', 'saveActiveItemAs', 'saveItem', 'saveItemAs', 'saveItems',
    'itemForUri', 'activateItemForUri', 'promptToSaveItem', 'copyActiveItem', 'isActive',
    'activate', 'getActiveItem', toProperty: 'model'

  previousActiveItem: null

  initialize: (args...) ->
    if args[0] instanceof Pane
      @model = args[0]
    else
      @model = new Pane(items: args)
      @model._view = this

    @onItemAdded(item) for item in @items
    @viewsByItem = new WeakMap()
    @handleEvents()

  handleEvents: ->
    @subscribe @model.$activeItem, @onActiveItemChanged
    @subscribe @model, 'item-added', @onItemAdded
    @subscribe @model, 'item-removed', @onItemRemoved
    @subscribe @model, 'item-moved', @onItemMoved
    @subscribe @model, 'before-item-destroyed', @onBeforeItemDestroyed
    @subscribe @model, 'activated', @onActivated
    @subscribe @model.$active, @onActiveStatusChanged

    @subscribe this, 'focusin', => @model.focus()
    @subscribe this, 'focusout', => @model.blur()
    @subscribe this, 'focus', =>
      @activeView?.focus()
      false

    @command 'pane:save-items', => @saveItems()
    @command 'pane:show-next-item', => @activateNextItem()
    @command 'pane:show-previous-item', => @activatePreviousItem()

    @command 'pane:show-item-1', => @activateItemAtIndex(0)
    @command 'pane:show-item-2', => @activateItemAtIndex(1)
    @command 'pane:show-item-3', => @activateItemAtIndex(2)
    @command 'pane:show-item-4', => @activateItemAtIndex(3)
    @command 'pane:show-item-5', => @activateItemAtIndex(4)
    @command 'pane:show-item-6', => @activateItemAtIndex(5)
    @command 'pane:show-item-7', => @activateItemAtIndex(6)
    @command 'pane:show-item-8', => @activateItemAtIndex(7)
    @command 'pane:show-item-9', => @activateItemAtIndex(8)

    @command 'pane:split-left', => @splitLeft(@copyActiveItem())
    @command 'pane:split-right', => @splitRight(@copyActiveItem())
    @command 'pane:split-up', => @splitUp(@copyActiveItem())
    @command 'pane:split-down', => @splitDown(@copyActiveItem())
    @command 'pane:close', =>
      @model.destroyItems()
      @model.destroy()
    @command 'pane:close-other-items', => @destroyInactiveItems()

  # Deprecated: Use ::destroyItem
  removeItem: (item) ->
    deprecate("Use PaneView::destroyItem instead")
    @destroyItem(item)

  # Deprecated: Use ::activateItem
  showItem: (item) ->
    deprecate("Use PaneView::activateItem instead")
    @activateItem(item)

  # Deprecated: Use ::activateItemForUri
  showItemForUri: (item) ->
    deprecate("Use PaneView::activateItemForUri instead")
    @activateItemForUri(item)

  # Deprecated: Use ::activateItemAtIndex
  showItemAtIndex: (index) ->
    deprecate("Use PaneView::activateItemAtIndex instead")
    @activateItemAtIndex(index)

  # Deprecated: Use ::activateNextItem
  showNextItem: ->
    deprecate("Use PaneView::activateNextItem instead")
    @activateNextItem()

  # Deprecated: Use ::activatePreviousItem
  showPreviousItem: ->
    deprecate("Use PaneView::activatePreviousItem instead")
    @activatePreviousItem()

  afterAttach: (onDom) ->
    @focus() if @model.focused and onDom

    return if @attached
    @container = @closest('.panes').view()
    @attached = true
    @trigger 'pane:attached', [this]

  onActivated: =>
    @focus() unless @hasFocus()

  onActiveStatusChanged: (active) =>
    if active
      @addClass('active')
      @trigger 'pane:became-active'
    else
      @removeClass('active')
      @trigger 'pane:became-inactive'

  # Public: Returns the next pane, ordered by creation.
  getNextPane: ->
    panes = @container?.getPaneViews()
    return unless panes.length > 1
    nextIndex = (panes.indexOf(this) + 1) % panes.length
    panes[nextIndex]

  getActivePaneItem: ->
    @activeItem

  onActiveItemChanged: (item) =>
    @previousActiveItem?.off? 'title-changed', @activeItemTitleChanged
    @previousActiveItem = item

    return unless item?

    hasFocus = @hasFocus()
    item.on? 'title-changed', @activeItemTitleChanged
    view = @viewForItem(item)
    otherView.hide() for otherView in @itemViews.children().not(view).views()
    @itemViews.append(view) unless view.parent().is(@itemViews)
    view.show() if @attached
    view.focus() if hasFocus

    @trigger 'pane:active-item-changed', [item]

  onItemAdded: (item, index) =>
    @trigger 'pane:item-added', [item, index]

  onItemRemoved: (item, index, destroyed) =>
    if item instanceof $
      viewToRemove = item
    else if viewToRemove = @viewsByItem.get(item)
      @viewsByItem.delete(item)

    if viewToRemove?
      if destroyed
        viewToRemove.remove()
      else
        viewToRemove.detach()

    @trigger 'pane:item-removed', [item, index]

  onItemMoved: (item, newIndex) =>
    @trigger 'pane:item-moved', [item, newIndex]

  onBeforeItemDestroyed: (item) =>
    @unsubscribe(item) if typeof item.off is 'function'
    @trigger 'pane:before-item-destroyed', [item]

  activeItemTitleChanged: =>
    @trigger 'pane:active-item-title-changed'

  viewForItem: (item) ->
    return unless item?
    if item instanceof $
      item
    else if view = @viewsByItem.get(item)
      view
    else
      viewClass = item.getViewClass()
      view = new viewClass(item)
      @viewsByItem.set(item, view)
      view

  @::accessor 'activeView', -> @viewForItem(@activeItem)

  splitLeft: (items...) -> @model.splitLeft({items})._view

  splitRight: (items...) -> @model.splitRight({items})._view

  splitUp: (items...) -> @model.splitUp({items})._view

  splitDown: (items...) -> @model.splitDown({items})._view

  # Public: Get the container view housing this pane.
  #
  # Returns a {View}.
  getContainer: ->
    @closest('.panes').view()

  beforeRemove: ->
    @model.destroy() unless @model.isDestroyed()

  remove: (selector, keepData) ->
    return super if keepData
    @unsubscribe()
    super
