{deprecate} = require 'grim'
Delegator = require 'delegato'
{$, View} = require './space-pen-extensions'
PaneView = require './pane-view'
PaneContainer = require './pane-container'

# Manages the list of panes within a {WorkspaceView}
module.exports =
class PaneContainerView extends View
  Delegator.includeInto(this)

  @delegatesMethod 'saveAll', toProperty: 'model'

  @content: ->
    @div()

  initialize: (params) ->
    if params instanceof PaneContainer
      @model = params
    else
      @model = new PaneContainer()

    if @model.orientation is 'vertical'
      @addClass 'pane-row'
    else
      @addClass 'pane-column'

    @subscribe @model, 'panes-reordered', => @onPanesReordered()

    @layoutPanes()

  viewForModel: (model) ->
    if model?
      viewClass = model.getViewClass()
      model._view ?= new viewClass(model)

  onPanesReordered: ->
    console.log "pane reorder"
    @children().detach()
    @layoutPanes()
    debugger

  layoutPanes: ->
    for pane in @model.panes
      @append(@viewForModel(pane))

  confirmClose: ->
    saved = true
    for paneView in @getPaneViews()
      for item in paneView.getItems()
        if not paneView.promptToSaveItem(item)
          saved = false
          break
    saved

  getPaneViews: ->
    @find('.pane').views()

  indexOfPane: (paneView) ->
    @getPaneViews().indexOf(paneView.view())

  paneAtIndex: (index) ->
    @getPaneViews()[index]

  eachPaneView: (callback) ->
    callback(paneView) for paneView in @getPaneViews()
    paneViewAttached = (e) -> callback($(e.target).view())
    @on 'pane:attached', paneViewAttached
    off: => @off 'pane:attached', paneViewAttached

  getFocusedPane: ->
    @find('.pane:has(:focus)').view()

  getActivePaneView: ->
    @viewForModel(@model.activePane)

  getActivePaneItem: ->
    @model.activePaneItem

  getActiveView: ->
    @getActivePaneView()?.activeView

  paneForUri: (uri) ->
    @viewForModel(@model.paneForUri(uri))

  focusNextPaneView: ->
    @model.activateNextPane()

  focusPreviousPaneView: ->
    @model.activatePreviousPane()

  focusPaneViewAbove: ->
    @nearestPaneInDirection('above')?.focus()

  focusPaneViewBelow: ->
    @nearestPaneInDirection('below')?.focus()

  focusPaneViewOnLeft: ->
    @nearestPaneInDirection('left')?.focus()

  focusPaneViewOnRight: ->
    @nearestPaneInDirection('right')?.focus()

  nearestPaneInDirection: (direction) ->
    distance = (pointA, pointB) ->
      x = pointB.x - pointA.x
      y = pointB.y - pointA.y
      Math.sqrt(Math.pow(x, 2) + Math.pow(y, 2))

    paneView = @getActivePaneView()
    box = @boundingBoxForPaneView(paneView)
    paneViews = @getPaneViews()
      .filter (otherPaneView) =>
        otherBox = @boundingBoxForPaneView(otherPaneView)
        switch direction
          when 'left' then otherBox.right.x <= box.left.x
          when 'right' then otherBox.left.x >= box.right.x
          when 'above' then otherBox.bottom.y <= box.top.y
          when 'below' then otherBox.top.y >= box.bottom.y
      .sort (paneViewA, paneViewB) =>
        boxA = @boundingBoxForPaneView(paneViewA)
        boxB = @boundingBoxForPaneView(paneViewB)
        switch direction
          when 'left' then distance(box.left, boxA.right) - distance(box.left, boxB.right)
          when 'right' then distance(box.right, boxA.left) - distance(box.right, boxB.left)
          when 'above' then distance(box.top, boxA.bottom) - distance(box.top, boxB.bottom)
          when 'below' then distance(box.bottom, boxA.top) - distance(box.bottom, boxB.top)

    paneViews[0]

  boundingBoxForPaneView: (paneView) ->
    boundingBox = paneView[0].getBoundingClientRect()

    left: {x: boundingBox.left, y: boundingBox.top}
    right: {x: boundingBox.right, y: boundingBox.top}
    top: {x: boundingBox.left, y: boundingBox.top}
    bottom: {x: boundingBox.left, y: boundingBox.bottom}

  getActivePane: ->
    deprecate("Use PaneContainerView::getActivePaneView instead.")
    @getActivePaneView()

  # Deprecated
  getPanes: ->
    deprecate("Use PaneContainerView::getPaneViews() instead")
    @getPaneViews()
