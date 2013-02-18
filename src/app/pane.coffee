{View} = require 'space-pen'
$ = require 'jquery'
PaneRow = require 'pane-row'
PaneColumn = require 'pane-column'

module.exports =
class Pane extends View
  @content: (wrappedView) ->
    @div class: 'pane', =>
      @div class: 'item-views', outlet: 'itemViews'

  @deserialize: ({wrappedView}) ->
    new Pane(deserialize(wrappedView))

  initialize: (@items...) ->
    @viewsByClassName = {}
    @showItem(@items[0])

  showItem: (item) ->
    @itemViews.children().hide()
    view = @viewForItem(item)
    unless view.parent().is(@itemViews)
      @itemViews.append(view)
    view.show()

  viewForItem: (item) ->
    if item instanceof $
      item
    else
      viewClass = item.getViewClass()
      if view = @viewsByClassName[viewClass.name]
        view.setModel(item)
        view
      else
        @viewsByClassName[viewClass.name] = new viewClass(item)


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
    view.focus?()
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

  buildPaneAxis: (axis) ->
    switch axis
      when 'row' then new PaneRow
      when 'column' then new PaneColumn
