{$, View} = require './space-pen-extensions'
Delegator = require 'delegato'
{deprecate} = require 'grim'
{CompositeDisposable} = require 'event-kit'
PropertyAccessors = require 'property-accessors'

Pane = require './pane'

# A container which can contains multiple items to be switched between.
#
# Items can be almost anything however most commonly they're {TextEditorView}s.
#
# Most packages won't need to use this class, unless you're interested in
# building a package that deals with switching between panes or items.
module.exports =
class PaneView extends View
  Delegator.includeInto(this)
  PropertyAccessors.includeInto(this)

  @delegatesProperties 'items', 'activeItem', toProperty: 'model'
  @delegatesMethods 'getItems', 'activateNextItem', 'activatePreviousItem', 'getActiveItemIndex',
    'activateItemAtIndex', 'activateItem', 'addItem', 'itemAtIndex', 'moveItem', 'moveItemToPane',
    'destroyItem', 'destroyItems', 'destroyActiveItem', 'destroyInactiveItems',
    'saveActiveItem', 'saveActiveItemAs', 'saveItem', 'saveItemAs', 'saveItems',
    'itemForUri', 'activateItemForUri', 'promptToSaveItem', 'copyActiveItem', 'isActive',
    'activate', 'getActiveItem', toProperty: 'model'

  previousActiveItem: null
  attached: false

  constructor: (@element) ->
    @itemViews = $(element.itemViews)
    super

  setModel: (@model) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add @model.observeActiveItem(@onActiveItemChanged)
    @subscriptions.add @model.onDidAddItem(@onItemAdded)
    @subscriptions.add @model.onDidRemoveItem(@onItemRemoved)
    @subscriptions.add @model.onDidMoveItem(@onItemMoved)
    @subscriptions.add @model.onWillDestroyItem(@onBeforeItemDestroyed)
    @subscriptions.add @model.observeActive(@onActiveStatusChanged)
    @subscriptions.add @model.onDidDestroy(@onPaneDestroyed)

  afterAttach: ->
    @container ?= @closest('atom-pane-container').view()
    @trigger('pane:attached', [this]) unless @attached
    @attached = true

  onPaneDestroyed: =>
    @container?.trigger 'pane:removed', [this]
    @subscriptions.dispose()

  remove: ->
    @model.destroy() unless @model.isDestroyed()

  # Essential: Returns the {Pane} model underlying this pane view
  getModel: -> @model

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

  onActiveStatusChanged: (active) =>
    if active
      @trigger 'pane:became-active'
    else
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
    @activeItemDisposables.dispose() if @activeItemDisposables?
    @activeItemDisposables = new CompositeDisposable()

    if @previousActiveItem?.off?
      @previousActiveItem.off 'title-changed', @activeItemTitleChanged
      @previousActiveItem.off 'modified-status-changed', @activeItemModifiedChanged
    @previousActiveItem = item

    return unless item?

    if item.onDidChangeTitle?
      disposable = item.onDidChangeTitle(@activeItemTitleChanged)
      deprecate 'Please return a Disposable object from your ::onDidChangeTitle method!' unless disposable?.dispose?
      @activeItemDisposables.add(disposable) if disposable?.dispose?
    else if item.on?
      deprecate 'If you would like your pane item to support title change behavior, please implement a ::onDidChangeTitle() method. ::on methods for items are no longer supported. If not, ignore this message.'
      disposable = item.on('title-changed', @activeItemTitleChanged)
      @activeItemDisposables.add(disposable) if disposable?.dispose?

    if item.onDidChangeModified?
      disposable = item.onDidChangeModified(@activeItemModifiedChanged)
      deprecate 'Please return a Disposable object from your ::onDidChangeModified method!' unless disposable?.dispose?
      @activeItemDisposables.add(disposable) if disposable?.dispose?
    else if item.on?
      deprecate 'If you would like your pane item to support modified behavior, please implement a ::onDidChangeModified() method. If not, ignore this message. ::on methods for items are no longer supported.'
      item.on('modified-status-changed', @activeItemModifiedChanged)
      @activeItemDisposables.add(disposable) if disposable?.dispose?

    @trigger 'pane:active-item-changed', [item]

  onItemAdded: ({item, index}) =>
    @trigger 'pane:item-added', [item, index]

  onItemRemoved: ({item, index, destroyed}) =>
    @trigger 'pane:item-removed', [item, index]

  onItemMoved: ({item, newIndex}) =>
    @trigger 'pane:item-moved', [item, newIndex]

  onBeforeItemDestroyed: ({item}) =>
    @unsubscribe(item) if typeof item.off is 'function'
    @trigger 'pane:before-item-destroyed', [item]

  activeItemTitleChanged: =>
    @trigger 'pane:active-item-title-changed'

  activeItemModifiedChanged: =>
    @trigger 'pane:active-item-modified-status-changed'

  @::accessor 'activeView', ->
    element = atom.views.getView(@activeItem)
    $(element).view() ? element

  splitLeft: (items...) -> atom.views.getView(@model.splitLeft({items})).__spacePenView

  splitRight: (items...) -> atom.views.getView(@model.splitRight({items})).__spacePenView

  splitUp: (items...) -> atom.views.getView(@model.splitUp({items})).__spacePenView

  splitDown: (items...) -> atom.views.getView(@model.splitDown({items})).__spacePenView

  getContainer: -> @closest('atom-pane-container').view()

  focus: ->
    @element.focus()
