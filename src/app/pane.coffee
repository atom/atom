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

  currentItem: null
  items: null

  initialize: (@items...) ->
    @viewsByClassName = {}
    @showItem(@items[0])

    @command 'core:close', @removeCurrentItem
    @command 'pane:show-next-item', @showNextItem
    @command 'pane:show-previous-item', @showPreviousItem
    @command 'pane:split-left', => @splitLeft()
    @command 'pane:split-right', => @splitRight()
    @command 'pane:split-up', => @splitUp()
    @command 'pane:split-down', => @splitDown()
    @on 'focus', =>
      @viewForCurrentItem().focus()
      false

  getItems: ->
    new Array(@items...)

  showNextItem: =>
    index = @getCurrentItemIndex()
    if index < @items.length - 1
      @showItemAtIndex(index + 1)
    else
      @showItemAtIndex(0)

  showPreviousItem: =>
    index = @getCurrentItemIndex()
    if index > 0
      @showItemAtIndex(index - 1)
    else
      @showItemAtIndex(@items.length - 1)

  getCurrentItemIndex: ->
    @items.indexOf(@currentItem)

  showItemAtIndex: (index) ->
    @showItem(@items[index])

  showItem: (item) ->
    @addItem(item)
    @itemViews.children().hide()
    view = @viewForItem(item)
    @itemViews.append(view) unless view.parent().is(@itemViews)
    @currentItem = item
    @currentView = view
    @currentView.show()

  addItem: (item) ->
    return if _.include(@items, item)
    @items.splice(@getCurrentItemIndex() + 1, 0, item)
    item

  removeCurrentItem: =>
    @removeItem(@currentItem)
    false

  removeItem: (item) ->
    @showNextItem() if item is @currentItem and @items.length > 1
    _.remove(@items, item)
    item.destroy?()
    @cleanupItemView(item)
    @remove() unless @items.length

  itemForPath: (path) ->
    _.detect @items, (item) -> item.getPath?() is path

  cleanupItemView: (item) ->
    if item instanceof $
      item.remove()
    else
      viewClass = item.getViewClass()
      otherItemsForView = @items.filter (i) -> i.getViewClass?() is viewClass
      unless otherItemsForView.length
        @viewsByClassName[viewClass.name].remove()
        delete @viewsByClassName[viewClass.name]

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

  viewForCurrentItem: ->
    @viewForItem(@currentItem)

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

    items = [@copyCurrentItem()] unless items.length
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

  copyCurrentItem: ->
    deserialize(@currentItem.serialize())

  remove: (selector, keepData) ->
    return super if keepData
    # find parent elements before removing from dom
    container = @getContainer()
    parentAxis = @parent('.row, .column')
    super
    if parentAxis.children().length == 1
      sibling = parentAxis.children().detach()
      parentAxis.replaceWith(sibling)
    container.adjustPaneDimensions()

  afterRemove: ->
    item.destroy?() for item in @getItems()
