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

  @deserialize: ({wrappedView}) ->
    new Pane(deserialize(wrappedView))

  currentItem: null
  items: null

  initialize: (@items...) ->
    @viewsByClassName = {}
    @showItem(@items[0])

    @command 'pane:show-next-item', @showNextItem
    @command 'pane:show-previous-item', @showPreviousItem
    @on 'focus', => @viewForCurrentItem().focus()

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
    unless view.parent().is(@itemViews)
      @itemViews.append(view)
    @currentItem = item
    view.show()

  addItem: (item) ->
    return if _.include(@items, item)
    @items.splice(@getCurrentItemIndex() + 1, 0, item)
    item

  removeItem: (item) ->
    @showNextItem() if item is @currentItem and @items.length > 1
    _.remove(@items, item)
    item.destroy?()
    @cleanupItemView(item)

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
    wrappedView: @wrappedView?.serialize()

  adjustDimensions: -> # do nothing

  horizontalGridUnits: -> 1

  verticalGridUnits: -> 1


  splitUp: (view) ->
    @split(view, 'column', 'before')

  splitDown: (view) ->
    @split(view, 'column', 'after')

  splitLeft: (view) ->
    @split(view, 'row', 'before')

  splitRight: (view) ->
    @split(view, 'row', 'after')

  split: (view, axis, side) ->
    unless @parent().hasClass(axis)
      @buildPaneAxis(axis)
        .insertBefore(this)
        .append(@detach())

    pane = new Pane(view)
    this[side](pane)
    rootView?.adjustPaneDimensions()
    pane.focus()
    pane

  remove: (selector, keepData) ->
    return super if keepData
    # find parent elements before removing from dom
    parentAxis = @parent('.row, .column')
    super
    if parentAxis.children().length == 1
      sibling = parentAxis.children().detach()
      parentAxis.replaceWith(sibling)
    rootView?.adjustPaneDimensions()

  afterRemove: ->
    item.destroy?() for item in @getItems()

  buildPaneAxis: (axis) ->
    switch axis
      when 'row' then new PaneRow
      when 'column' then new PaneColumn
