{View} = require './space-pen-extensions'
Pane = null

### Internal ###
module.exports =
class PaneAxis extends View
  initialize: (@model) ->
    @onChildAdded(child) for child in @model.children
    @subscribe @model.children, 'changed', @onChildrenChanged

  viewForModel: (model) ->
    viewClass = model.getViewClass()
    model._view ?= new viewClass(model)

  addChild: (child, index) ->
    @model.addChild(child.model, index)

  removeChild: (child) ->
    @model.removeChild(child.model)

  onChildrenChanged:  ({index, removedValues, insertedValues}) =>
    focusedElement = document.activeElement if @hasFocus()
    @onChildRemoved(child, index) for child in removedValues
    @onChildAdded(child, index + i) for child, i in insertedValues
    focusedElement?.focus() if document.activeElement is document.body

  onChildAdded: (child, index) =>
    view = @viewForModel(child)
    @insertAt(index, view)

  onChildRemoved: (child) =>
    view = @viewForModel(child)
    view.detach()
    Pane ?= require './pane'

    if view instanceof Pane and view.model.isDestroyed()
      @getContainer()?.trigger 'pane:removed', [view]

  getContainer: ->
    @closest('.panes').view()

  getActivePaneItem: ->
    @getActivePane()?.activeItem

  getActivePane: ->
    @find('.pane.active').view() ? @find('.pane:first').view()

  insertChildBefore: (currentChild, newChild) ->
    @model.insertChildBefore(currentChild, newChild)

  insertChildAfter: (currentChild, newChild) ->
    @model.insertChildAfter(currentChild, newChild)
