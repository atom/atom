{deprecate} = require 'grim'
Delegator = require 'delegato'
{CompositeDisposable} = require 'event-kit'
{$, View} = require './space-pen-extensions'
PaneView = require './pane-view'
PaneContainer = require './pane-container'

# Manages the list of panes within a {WorkspaceView}
module.exports =
class PaneContainerView extends View
  Delegator.includeInto(this)

  @delegatesMethod 'saveAll', toProperty: 'model'

  @content: ->
    @div class: 'panes'

  initialize: (params) ->
    @subscriptions = new CompositeDisposable

    if params instanceof PaneContainer
      @model = params
    else
      @model = new PaneContainer({root: params?.root?.model})

    @subscriptions.add @model.observeRoot(@onRootChanged)
    @subscriptions.add @model.onDidChangeActivePaneItem(@onActivePaneItemChanged)

  getRoot: ->
    @children().first().view()

  onRootChanged: (root) =>
    focusedElement = document.activeElement if @hasFocus()

    oldRoot = @getRoot()
    if oldRoot instanceof PaneView and oldRoot.model.isDestroyed()
      @trigger 'pane:removed', [oldRoot]
    oldRoot?.detach()
    if root?
      view = @model.getView(root).__spacePenView
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

  getActivePane: ->
    deprecate("Use PaneContainerView::getActivePaneView instead.")
    @getActivePaneView()

  getActivePaneView: ->
    @model.getView(@model.getActivePane()).__spacePenView

  getActivePaneItem: ->
    @model.getActivePaneItem()

  getActiveView: ->
    @getActivePaneView()?.activeView

  paneForUri: (uri) ->
    @model.getView(@model.paneForUri(uri)).__spacePenView

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

  # Deprecated
  getPanes: ->
    deprecate("Use PaneContainerView::getPaneViews() instead")
    @getPaneViews()

  beforeRemove: ->
    @subscriptions.dispose()
