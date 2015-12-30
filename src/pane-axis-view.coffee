{View} = require './space-pen-extensions'
PaneView = null

module.exports =
class PaneAxisView extends View
  initialize: (@model) ->
    @onChildAdded(child) for child in @model.children
    @subscribe @model.children, 'changed', @onChildrenChanged

  afterAttach: ->
    @container = @closest('.panes').view()

  viewForModel: (model) ->
    viewClass = model.getViewClass()
    model._view ?= new viewClass(model)

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
    PaneView ?= require './pane-view'
    if view instanceof PaneView and view.model.isDestroyed()
      @container?.trigger 'pane:removed', [view]
