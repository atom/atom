{View} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'
PaneRow = require 'pane-row'
PaneColumn = require 'pane-column'

module.exports =
class Pane extends View

  ### Internal ###

  @content: (wrappedView) ->
    @div class: 'pane', =>
      @div class: 'item-views', outlet: 'itemViews'

  @deserialize: ({items, focused, activeItemUri}) ->
    deserializedItems = _.compact(items.map((item) -> deserialize(item)))
    pane = new Pane(deserializedItems...)
    pane.showItemForUri(activeItemUri) if activeItemUri
    pane.focusOnAttach = true if focused
    pane

  activeItem: null
  items: null

  initialize: (@items...) ->
    @viewsByClassName = {}
    @showItem(@items[0]) if @items.length > 0

    @command 'core:close', @destroyActiveItem
    @command 'core:save', @saveActiveItem
    @command 'core:save-as', @saveActiveItemAs
    @command 'pane:save-items', @saveItems
    @command 'pane:show-next-item', @showNextItem
    @command 'pane:show-previous-item', @showPreviousItem

    @command 'pane:show-item-1', => @showItemAtIndex(0)
    @command 'pane:show-item-2', => @showItemAtIndex(1)
    @command 'pane:show-item-3', => @showItemAtIndex(2)
    @command 'pane:show-item-4', => @showItemAtIndex(3)
    @command 'pane:show-item-5', => @showItemAtIndex(4)
    @command 'pane:show-item-6', => @showItemAtIndex(5)
    @command 'pane:show-item-7', => @showItemAtIndex(6)
    @command 'pane:show-item-8', => @showItemAtIndex(7)
    @command 'pane:show-item-9', => @showItemAtIndex(8)

    @command 'pane:split-left', => @splitLeft()
    @command 'pane:split-right', => @splitRight()
    @command 'pane:split-up', => @splitUp()
    @command 'pane:split-down', => @splitDown()
    @command 'pane:close', => @destroyItems()
    @command 'pane:close-other-items', => @destroyInactiveItems()
    @on 'focus', => @activeView?.focus(); false
    @on 'focusin', => @makeActive()
    @on 'focusout', => @autosaveActiveItem()

  afterAttach: (onDom) ->
    if @focusOnAttach and onDom
      @focusOnAttach = null
      @focus()

    return if @attached
    @attached = true
    @trigger 'pane:attached', [this]

  ### Public ###

  makeActive: ->
    for pane in @getContainer().getPanes() when pane isnt this
      pane.makeInactive()
    wasActive = @isActive()
    @addClass('active')
    @trigger 'pane:became-active' unless wasActive

  makeInactive: ->
    @removeClass('active')

  isActive: ->
    @hasClass('active')

  getNextPane: ->
    panes = @getContainer()?.getPanes()
    return unless panes.length > 1
    nextIndex = (panes.indexOf(this) + 1) % panes.length
    panes[nextIndex]

  getItems: ->
    new Array(@items...)

  showNextItem: =>
    index = @getActiveItemIndex()
    if index < @items.length - 1
      @showItemAtIndex(index + 1)
    else
      @showItemAtIndex(0)

  showPreviousItem: =>
    index = @getActiveItemIndex()
    if index > 0
      @showItemAtIndex(index - 1)
    else
      @showItemAtIndex(@items.length - 1)

  getActiveItemIndex: ->
    @items.indexOf(@activeItem)

  showItemAtIndex: (index) ->
    @showItem(@itemAtIndex(index))

  itemAtIndex: (index) ->
    @items[index]

  showItem: (item) ->
    return if !item? or item is @activeItem

    if @activeItem
      @activeItem.off? 'title-changed', @activeItemTitleChanged
      @autosaveActiveItem()

    isFocused = @is(':has(:focus)')
    @addItem(item)
    item.on? 'title-changed', @activeItemTitleChanged
    view = @viewForItem(item)
    @itemViews.children().not(view).hide()
    @itemViews.append(view) unless view.parent().is(@itemViews)
    view.show()
    view.focus() if isFocused
    @activeItem = item
    @activeView = view
    @trigger 'pane:active-item-changed', [item]

  activeItemTitleChanged: =>
    @trigger 'pane:active-item-title-changed'

  addItem: (item) ->
    return if _.include(@items, item)
    index = @getActiveItemIndex() + 1
    @items.splice(index, 0, item)
    @getContainer().itemAdded(item)
    @trigger 'pane:item-added', [item, index]
    item

  destroyActiveItem: =>
    @destroyItem(@activeItem)
    false

  destroyItem: (item) ->
    container = @getContainer()
    reallyDestroyItem = =>
      @removeItem(item)
      container.itemDestroyed(item)
      item.destroy?()

    @autosaveItem(item)

    if item.shouldPromptToSave?()
      reallyDestroyItem() if @promptToSaveItem(item)
    else
      reallyDestroyItem()

  destroyItems: ->
    @destroyItem(item) for item in @getItems()

  destroyInactiveItems: ->
    @destroyItem(item) for item in @getItems() when item isnt @activeItem

  promptToSaveItem: (item) ->
    uri = item.getUri()
    currentWindow = require('remote').getCurrentWindow()
    chosen = atom.confirmSync(
      "'#{item.getTitle?() ? item.getUri()}' has changes, do you want to save them?"
      "Your changes will be lost if you close this item without saving."
      ["Save", "Cancel", "Don't Save"]
      currentWindow
    )
    switch chosen
      when 0 then @saveItem(item, -> true)
      when 1 then false
      when 2 then true

  saveActiveItem: =>
    @saveItem(@activeItem)

  saveActiveItemAs: =>
    @saveItemAs(@activeItem)

  saveItem: (item, nextAction) ->
    if item.getUri?()
      item.save?()
      nextAction?()
    else
      @saveItemAs(item, nextAction)

  saveItemAs: (item, nextAction) ->
    return unless item.saveAs?
    path = atom.showSaveDialogSync()
    if path
      item.saveAs(path)
      nextAction?()

  saveItems: =>
    @saveItem(item) for item in @getItems()

  autosaveActiveItem: ->
    @autosaveItem(@activeItem)

  autosaveItem: (item) ->
    @saveItem(item) if config.get('core.autosave') and item.getUri?()

  removeItem: (item) ->
    index = @items.indexOf(item)
    return if index == -1

    @showNextItem() if item is @activeItem and @items.length > 1
    _.remove(@items, item)
    @cleanupItemView(item)
    @trigger 'pane:item-removed', [item, index]

  moveItem: (item, newIndex) ->
    oldIndex = @items.indexOf(item)
    @items.splice(oldIndex, 1)
    @items.splice(newIndex, 0, item)
    @trigger 'pane:item-moved', [item, newIndex]

  moveItemToPane: (item, pane, index) ->
    @isMovingItem = true
    @removeItem(item)
    @isMovingItem = false
    pane.addItem(item, index)

  itemForUri: (uri) ->
    _.detect @items, (item) -> item.getUri?() is uri

  showItemForUri: (uri) ->
    @showItem(@itemForUri(uri))

  cleanupItemView: (item) ->
    if item instanceof $
      viewToRemove = item
    else
      viewClass = item.getViewClass()
      otherItemsForView = @items.filter (i) -> i.getViewClass?() is viewClass
      unless otherItemsForView.length
        viewToRemove = @viewsByClassName[viewClass.name]
        viewToRemove?.setModel(null)
        delete @viewsByClassName[viewClass.name]

    if @items.length > 0
      if @isMovingItem and item is viewToRemove
        viewToRemove?.detach()
      else
        viewToRemove?.remove()
    else
      viewToRemove?.detach() if @isMovingItem and item is viewToRemove
      @remove()

  viewForItem: (item) ->
    if item instanceof $
      item
    else
      viewClass = item.getViewClass()
      if view = @viewsByClassName[viewClass.name]
        view.setModel(item)
      else
        view = @viewsByClassName[viewClass.name] = new viewClass(item)
      view

  viewForActiveItem: ->
    @viewForItem(@activeItem)

  serialize: ->
    deserializer: "Pane"
    focused: @is(':has(:focus)')
    activeItemUri: @activeItem.getUri?() if typeof @activeItem.serialize is 'function'
    items: _.compact(@getItems().map (item) -> item.serialize?())

  adjustDimensions: -> # do nothing

  horizontalGridUnits: -> 1

  verticalGridUnits: -> 1

  splitUp: (items...) ->
    @split(items, 'column', 'before')

  splitDown: (items...) ->
    @split(items, 'column', 'after')

  splitLeft: (items...) ->
    @split(items, 'row', 'before')

  splitRight: (items...) ->
    @split(items, 'row', 'after')

  split: (items, axis, side) ->
    unless @parent().hasClass(axis)
      @buildPaneAxis(axis)
        .insertBefore(this)
        .append(@detach())

    items = [@copyActiveItem()] unless items.length
    pane = new Pane(items...)
    this[side](pane)
    @getContainer().adjustPaneDimensions()
    pane.focus()
    pane

  buildPaneAxis: (axis) ->
    switch axis
      when 'row' then new PaneRow
      when 'column' then new PaneColumn

  getContainer: ->
    @closest('#panes').view()

  copyActiveItem: ->
    deserialize(@activeItem.serialize())

  remove: (selector, keepData) ->
    return super if keepData

    # find parent elements before removing from dom
    container = @getContainer()
    parentAxis = @parent('.row, .column')

    if @is(':has(:focus)')
      container.focusNextPane() or rootView?.focus()
    else if @isActive()
      container.makeNextPaneActive()

    super

    if parentAxis.children().length == 1
      sibling = parentAxis.children()
      siblingFocused = sibling.is(':has(:focus)')
      sibling.detach()
      parentAxis.replaceWith(sibling)
      sibling.focus() if siblingFocused
    container.adjustPaneDimensions()
    container.trigger 'pane:removed', [this]

  beforeRemove: ->
    item.destroy?() for item in @getItems()
