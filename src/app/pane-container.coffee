{View, $$} = require 'space-pen'

class PaneContainer extends View
  @content ->
    @div id: 'panes'

  getWindowState: ->
    @childWindowStates()[0]

  childWindowStates: ->
    @children().toArray().map (element) ->
      $(element).view().getWindowState()

  setWindowState: (windowState) ->
    @empty()
    @appendChild(windowState)
    @adjustSplitPanes()

  appendChild: (state) ->
    [type, args...] = windowState
    switch type
      when 'editor'
        editor = new Editor(args...)
        @parentView.paneAdded(editor)
        @append(editor)
      when 'row'
        @append(new Row(this, args))
      when 'column'
        @append(new Column(this, args))

  addPaneLeft: (view, sibling) ->
    @addPane(view, sibling, Row, 'before')

  addPaneRight: (view, sibling) ->
    @addPane(view, sibling, Row, 'after')

  addPaneAbove: (view, sibling) ->
    @addPane(view, sibling, Column, 'before')

  addPaneBelow: (view, sibling) ->
    @addPane(view, sibling, Column, 'after')

  addPane: (view, sibling, axisClass, side) ->
    unless sibling.parent().hasClass(axis)
      container = new axisClass(this)
      container.insertBefore(sibling).append(sibling.detach())
    sibling[side](view)
    @adjustSplitPanes()
    view

  adjustSplitPanes: ->
    if @hasClass('row')
      totalUnits = @horizontalGridUnits(element)
      unitsSoFar = 0
      for child in element.children()
        child = $(child)
        childUnits = @horizontalGridUnits(child)
        child.css
          width: "#{childUnits / totalUnits * 100}%"
          height: '100%'
          top: 0
          left: "#{unitsSoFar / totalUnits * 100}%"
        @adjustSplitPanes(child)
        unitsSoFar += childUnits

    else if element.hasClass('column')
      totalUnits = @verticalGridUnits(element)
      unitsSoFar = 0
      for child in element.children()
        child = $(child)
        childUnits = @verticalGridUnits(child)
        child.css
          width: '100%'
          height: "#{childUnits / totalUnits * 100}%"
          top: "#{unitsSoFar / totalUnits * 100}%"
          left: 0
        @adjustSplitPanes(child)
        unitsSoFar += childUnits
######

  horizontalGridUnits: (element) ->
    if element.is('.row, .column')
      childUnits = (@horizontalGridUnits($(child)) for child in element.children())
      if element.hasClass('row')
        _.sum(childUnits)
      else # it's a column
        Math.max(childUnits...)
    else
      1

  verticalGridUnits: (element) ->
    if element.is('.row, .column')
      childUnits = (@verticalGridUnits($(child)) for child in element.children())
      if element.hasClass('column')
        _.sum(childUnits)
      else # it's a row
        Math.max(childUnits...)
    else
      1

class Row extends PaneContainer
  @content ->
    @div class: 'row'

  initialize: (@parentView, children=[]) ->
    @appendChild(child) for child in children

  getWindowState: ->
    ['row'].concat(@childWindowStates())

class Column extends PaneContainer
  @content ->
    @div class: 'column'

  initialize: (@parentView, children=[]) ->
    @appendChild(child) for child in children

  getWindowState: ->
    ['column'].concat(@childWindowStates())


module.exports = { Column, Row }
