$ = require 'jquery'
_ = require 'underscore'
PaneGrid = require 'app/pane-grid'

module.exports =
class PaneColumn extends PaneGrid
  @content: ->
    @div class: 'column'

  className: ->
    "PaneColumn"

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
    Math.max(@horizontalChildUnits()...)

  verticalGridUnits:   ->
    _.sum(@verticalChildUnits())
