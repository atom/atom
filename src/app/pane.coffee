{View} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'
PaneRow = require 'pane-row'
PaneColumn = require 'pane-column'

module.exports =
class Pane extends View
  @content: (wrappedView) ->
    @div class: 'pane', =>
      @div class: 'item-views', outlet: 'itemViews'

  @deserialize: ({items}) ->
    new Pane(items.map((item) -> deserialize(item))...)

  activeItem: null
  items: null

  initialize: (@items...) ->
    @viewsByClassName = {}
    @showItem(@items[0])

    @command 'core:close', @destroyActiveItem
    @command 'pane:show-next-item', @showNextItem
    @command 'pane:show-previous-item', @showPreviousItem
    @command 'pane:split-left', => @splitLeft()
    @command 'pane:split-right', => @splitRight()
    @command 'pane:split-up', => @splitUp()
    @command 'pane:split-down', => @splitDown()
    @on 'focus', => @activeView.focus(); false
    @on 'focusin', => @makeActive()

  afterAttach: ->
    return if @attached
    @attached = true
    @trigger 'pane:attached'

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
    @showItem(@items[index])

  showItem: (item) ->
    return if item is @activeItem
    isFocused = @is(':has(:focus)')
    @addItem(item)
    view = @viewForItem(item)
    @itemViews.children().not(view).hide()
    @itemViews.append(view) unless view.parent().is(@itemViews)
    view.show()
    view.focus() if isFocused
    @activeItem = item
    @activeView = view
    @trigger 'pane:active-item-changed', [item]

  addItem: (item) ->
    return if _.include(@items, item)
    index = @getActiveItemIndex() + 1
    @items.splice(index, 0, item)
    @trigger 'pane:item-added', [item, index]
    item

  destroyActiveItem: =>
    @destroyItem(@activeItem)
    false

  destroyItem: (item) ->
    reallyDestroyItem = =>
      @removeItem(item)
      item.destroy?()

    if item.isModified?()
      @promptToSaveItem(item, reallyDestroyItem)
    else
      reallyDestroyItem()

  promptToSaveItem: (item, nextAction) ->
    path = item.getPath()
    atom.confirm(
      "'#{item.getTitle()}' has changes, do you want to save them?"
      "Your changes will be lost if close this item without saving."
      "Save", => @saveItem(item, nextAction)
      "Cancel", null
      "Don't Save", nextAction
    )

  saveItem: (item, nextAction) ->
    if item.getPath()
      item.save()
      nextAction()
    else
      atom.showSaveDialog (path) ->
        item.saveAs(path)
        nextAction()

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
    @removeItem(item)
    pane.addItem(item, index)

  itemForPath: (path) ->
    _.detect @items, (item) -> item.getPath?() is path

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
      viewToRemove?.remove()
    else
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

  afterRemove: ->
    item.destroy?() for item in @getItems()
