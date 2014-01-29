Delegator = require 'delegato'
{$, View} = require './space-pen-extensions'
PaneView = require './pane-view'
PaneContainer = require './pane-container'

# Private: Manages the list of panes within a {WorkspaceView}
module.exports =
class PaneContainerView extends View
  Delegator.includeInto(this)

  @delegatesMethod 'saveAll', toProperty: 'model'

  @content: ->
    @div class: 'panes'

  initialize: (params) ->
    if params instanceof PaneContainer
      @model = params
    else
      @model = new PaneContainer({root: params?.root?.model})

    @subscribe @model.$root, @onRootChanged
    @subscribe @model.$activePaneItem.changes, @onActivePaneItemChanged

  viewForModel: (model) ->
    if model?
      viewClass = model.getViewClass()
      model._view ?= new viewClass(model)

  ### Public ###

  getRoot: ->
    @children().first().view()

  onRootChanged: (root) =>
    focusedElement = document.activeElement if @hasFocus()

    oldRoot = @getRoot()
    if oldRoot instanceof PaneView and oldRoot.model.isDestroyed()
      @trigger 'pane:removed', [oldRoot]
    oldRoot?.detach()
    if root?
      view = @viewForModel(root)
      @append(view)
      focusedElement?.focus()
    else
      atom.workspaceView?.focus() if focusedElement?

  onActivePaneItemChanged: (activeItem) =>
    @trigger 'pane-container:active-pane-item-changed', [activeItem]

  removeChild: (child) ->
    throw new Error("Removing non-existant child") unless @getRoot() is child
    @setRoot(null)
    @trigger 'pane:removed', [child] if child instanceof PaneView

  confirmClose: ->
    saved = true
    for pane in @getPanes()
      for item in pane.getItems()
        if not pane.promptToSaveItem(item)
          saved = false
          break
    saved

  getPanes: ->
    @find('.pane').views()

  indexOfPane: (pane) ->
    @getPanes().indexOf(pane.view())

  paneAtIndex: (index) ->
    @getPanes()[index]

  eachPane: (callback) ->
    callback(pane) for pane in @getPanes()
    paneAttached = (e) -> callback($(e.target).view())
    @on 'pane:attached', paneAttached
    off: => @off 'pane:attached', paneAttached

  getFocusedPane: ->
    @find('.pane:has(:focus)').view()

  getActivePane: ->
    @viewForModel(@model.activePane)

  getActivePaneItem: ->
    @model.activePaneItem

  getActiveView: ->
    @getActivePane()?.activeView

  paneForUri: (uri) ->
    @viewForModel(@model.paneForUri(uri))

  focusNextPane: ->
    @model.activateNextPane()

  focusPreviousPane: ->
    @model.activatePreviousPane()

  focusPaneAbove: ->
    @nearestPaneInDirection('above')?.focus()

  focusPaneBelow: ->
    @nearestPaneInDirection('below')?.focus()

  focusPaneOnLeft: ->
    @nearestPaneInDirection('left')?.focus()

  focusPaneOnRight: ->
    @nearestPaneInDirection('right')?.focus()

  nearestPaneInDirection: (direction) ->
    pane = @getActivePane()
    box = @boundingBoxForPane(pane)
    panes = @getPanes()
      .filter (otherPane) =>
        otherBox = @boundingBoxForPane(otherPane)
        switch direction
          when 'left' then otherBox.right.x <= box.left.x
          when 'right' then otherBox.left.x >= box.right.x
          when 'above' then otherBox.bottom.y <= box.top.y
          when 'below' then otherBox.top.y >= box.bottom.y
      .sort (paneA, paneB) =>
        boxA = @boundingBoxForPane(paneA)
        boxB = @boundingBoxForPane(paneB)
        switch direction
          when 'left'
            @distanceBetweenPoints(box.left, boxA.right) - @distanceBetweenPoints(box.left, boxB.right)
          when 'right'
            @distanceBetweenPoints(box.right, boxA.left) - @distanceBetweenPoints(box.right, boxB.left)
          when 'above'
            @distanceBetweenPoints(box.top, boxA.bottom) - @distanceBetweenPoints(box.top, boxB.bottom)
          when 'below'
            @distanceBetweenPoints(box.bottom, boxA.top) - @distanceBetweenPoints(box.bottom, boxB.top)

    panes[0]

  boundingBoxForPane: (pane) ->
    boundingBox = pane[0].getBoundingClientRect()

    left: {x: boundingBox.left, y: boundingBox.top}
    right: {x: boundingBox.right, y: boundingBox.top}
    top: {x: boundingBox.left, y: boundingBox.top}
    bottom: {x: boundingBox.left, y: boundingBox.bottom}

  distanceBetweenPoints: (pointA, pointB) ->
    x = pointB.x - pointA.x
    y = pointB.y - pointA.y
    Math.sqrt(Math.pow(x, 2) + Math.pow(y, 2));
