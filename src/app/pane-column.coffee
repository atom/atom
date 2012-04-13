$ = require 'jquery'
_ = require 'underscore'
{View} = require 'space-pen'
Pane = require 'pane'

module.exports =
class PaneColumn extends View
  @content: ->
    @div class: 'column'

  @deserialize: ({children}, rootView) ->
    childViews = children.map (child) -> rootView.deserializeView(child)
    new PaneColumn(childViews)

  initialize: (children=[]) ->
    @append(children...)

  serialize: ->
    viewClass: "PaneColumn"
    children: @childViewStates()

  childViewStates: ->
    $(child).view().serialize() for child in @children()

  adjustDimensions: ->
    totalUnits = @verticalGridUnits()
    unitsSoFar = 0
    for child in @children()
      child = $(child).view()
      childUnits = child.verticalGridUnits()
      child.css
        width: '100%'
        height: "#{childUnits / totalUnits * 100}%"
        top: "#{unitsSoFar / totalUnits * 100}%"
        left: 0

      child.adjustDimensions()
      unitsSoFar += childUnits

  horizontalGridUnits: ->
    childUnits = ($(child).view().horizontalGridUnits() for child in @children())
    Math.max(childUnits...)

  verticalGridUnits:   ->
    childUnits = ($(child).view().verticalGridUnits() for child in @children())
    _.sum(childUnits)