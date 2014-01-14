{$, View} = require './space-pen-extensions'
Delegator = require 'delegato'
PropertyAccessors = require 'property-accessors'

Pane = require './pane'

# Public: A container which can contains multiple items to be switched between.
#
# Items can be almost anything however most commonly they're {EditorView}s.
#
# Most packages won't need to use this class, unless you're interested in
# building a package that deals with switching between panes or tiems.
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
    'activate', toProperty: 'model'

  previousActiveItem: null

  # Private:
  initialize: (args...) ->
    if args[0] instanceof Pane
      @model = args[0]
    else
      @model = new Pane(items: args)
      @model._view = this

    @onItemAdded(item) for item in @items
    @handleEvents()

  handleEvents: ->
    @subscribe @model, 'destroyed', => @remove()

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
    @command 'pane:close', => @destroyItems()
    @command 'pane:close-other-items', => @destroyInactiveItems()

  # Deprecated: Use ::destroyItem
  removeItem: (item) -> @destroyItem(item)

  # Deprecated: Use ::activateItem
  showItem: (item) -> @activateItem(item)

  # Deprecated: Use ::activateItemForUri
  showItemForUri: (item) -> @activateItemForUri(item)

  # Deprecated: Use ::activateItemAtIndex
  showItemAtIndex: (index) -> @activateItemAtIndex(index)

  # Deprecated: Use ::activateNextItem
  showNextItem: -> @activateNextItem()

  # Deprecated: Use ::activatePreviousItem
  showPreviousItem: -> @activatePreviousItem()

  # Private:
  afterAttach: (onDom) ->
    @focus() if @model.focused and onDom

    return if @attached
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

    hasFocus = @hasFocus()
    item.on? 'title-changed', @activeItemTitleChanged
    view = @viewForItem(item)
    @itemViews.children().not(view).hide()
    @itemViews.append(view) unless view.parent().is(@itemViews)
    view.show() if @attached
    view.focus() if hasFocus

    @trigger 'pane:active-item-changed', [item]

  onItemAdded: (item, index) =>
    @trigger 'pane:item-added', [item, index]

  onItemRemoved: (item, index, destroyed) =>
    if item instanceof $
      viewToRemove = item
    else if viewToRemove = atom.views.find(item)
      atom.views.remove(item, viewToRemove) if destroyed

    if viewToRemove?
      viewToRemove.setModel?(null)
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

  # Private:
  activeItemTitleChanged: =>
    @trigger 'pane:active-item-title-changed'

  # Private:
  viewForItem: (item) ->
    return unless item?
    if item instanceof $
      item
    else
      atom.views.findOrCreate(item)

  # Private:
  @::accessor 'activeView', -> @viewForItem(@activeItem)

  splitLeft: (items...) -> @model.splitLeft({items})._view

  splitRight: (items...) -> @model.splitRight({items})._view

  splitUp: (items...) -> @model.splitUp({items})._view

  splitDown: (items...) -> @model.splitDown({items})._view

  # Private:
  getContainer: ->
    @closest('.panes').view()

  beforeRemove: ->
    @model.destroy() unless @model.isDestroyed()

  # Private:
  remove: (selector, keepData) ->
    return super if keepData
    @unsubscribe()
    super
