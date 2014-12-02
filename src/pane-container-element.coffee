{CompositeDisposable} = require 'event-kit'
{callAttachHooks} = require './space-pen-extensions'
PaneContainerView = null
_ = require 'underscore-plus'

module.exports =
class PaneContainerElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @classList.add 'panes'
    PaneContainerView ?= require './pane-container-view'
    @__spacePenView = new PaneContainerView(this)

  initialize: (@model) ->
    @subscriptions.add @model.observeRoot(@rootChanged.bind(this))
    @__spacePenView.setModel(@model)
    this

  rootChanged: (root) ->
    focusedElement = document.activeElement if @hasFocus()
    @firstChild?.remove()
    if root?
      view = atom.views.getView(root)
      @appendChild(view)
      callAttachHooks(view)
      focusedElement?.focus()

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

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

    paneView = atom.views.getView(@model.getActivePane())
    box = @boundingBoxForPaneView(paneView)

    paneViews = _.toArray(@querySelectorAll('atom-pane'))
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
    boundingBox = paneView.getBoundingClientRect()

    left: {x: boundingBox.left, y: boundingBox.top}
    right: {x: boundingBox.right, y: boundingBox.top}
    top: {x: boundingBox.left, y: boundingBox.top}
    bottom: {x: boundingBox.left, y: boundingBox.bottom}

module.exports = PaneContainerElement = document.registerElement 'atom-pane-container', prototype: PaneContainerElement.prototype
