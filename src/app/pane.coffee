{View} = require 'space-pen'
PaneRow = require 'pane-row'
PaneColumn = require 'pane-column'

module.exports =
class Pane extends View
  @content: (wrappedView) ->
    @div class: 'pane', =>
      @subview 'wrappedView', wrappedView

  @deserialize: ({wrappedView}, rootView) ->
    new Pane(rootView.deserializeView(wrappedView))

  serialize: ->
    viewClass: "Pane"
    wrappedView: @wrappedView.serialize()

  adjustDimensions: -> # do nothing

  horizontalGridUnits: ->
    1

  verticalGridUnits: ->
    1

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
    @rootView().adjustPaneDimensions()
    view.focus?()
    pane

  remove: (selector, keepData) ->
    return super if keepData
    # find parent elements before removing from dom
    parentAxis = @parent('.row, .column')
    rootView = @rootView()
    super
    if parentAxis.children().length == 1
      sibling = parentAxis.children().detach()
      parentAxis.replaceWith(sibling)
    rootView.adjustPaneDimensions()

  buildPaneAxis: (axis) ->
    switch axis
      when 'row' then new PaneRow
      when 'column' then new PaneColumn

  rootView: ->
    @parents('#root-view').view()
