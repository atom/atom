$ = require 'jquery'
_ = require 'underscore'
{View} = require 'space-pen'
Pane = require 'pane'

module.exports =
class PaneRow extends View
  @content: ->
    @div class: 'row'

  @deserialize: ({children}, rootView) ->
    childViews = children.map (child) -> rootView.deserializeView(child)
    new PaneRow(childViews)

  initialize: (children=[]) ->
    @append(children...)

  serialize: ->
    viewClass: "PaneRow"
    children: @childViewStates()

  childViewStates: ->
    $(child).view().serialize() for child in @children()

  adjustDimensions: ->
    totalUnits = @horizontalGridUnits()
    unitsSoFar = 0
    for child in @children()
      child = $(child).view()
      childUnits = child.horizontalGridUnits()
      child.css
        width: "#{childUnits / totalUnits * 100}%"
        height: '100%'
        top: 0
        left: "#{unitsSoFar / totalUnits * 100}%"
      child.adjustDimensions()
      unitsSoFar += childUnits

  horizontalGridUnits: ->
    childUnits = ($(child).view().horizontalGridUnits() for child in @children())
    _.sum(childUnits)

  verticalGridUnits: ->
    childUnits = ($(child).view().verticalGridUnits() for child in @children())
    Math.max(childUnits...)
