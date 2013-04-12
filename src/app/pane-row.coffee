$ = require 'jquery'
_ = require 'underscore'
PaneAxis = require 'pane-axis'

module.exports =
class PaneRow extends PaneAxis
  @content: ->
    @div class: 'row'

  # Public: Retrieves the pane class name.
  #
  # Returns a {String}.
  className: ->
    "PaneRow"

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
    _.sum(@horizontalChildUnits())

  verticalGridUnits: ->
    Math.max(@verticalChildUnits()...)
