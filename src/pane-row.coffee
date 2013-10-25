{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
PaneAxis = require './pane-axis'

### Internal ###

module.exports =
class PaneRow extends PaneAxis
  @content: ->
    @div class: 'row'

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
