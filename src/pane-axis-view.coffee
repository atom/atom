{View} = require './space-pen-extensions'
PaneView = null

### Internal ###
module.exports =
class PaneAxisView extends View
  @content: (model) ->
    orientationClass =
      if model.orientation is 'horizontal'
        'pane-row'
      else
        'pane-column'

    @div class: orientationClass

  initialize: (@model) ->
    @onChildAdded(child) for child in @model.children
    @subscribe @model.children, 'changed', @onChildrenChanged

  onChildrenChanged:  ({index, removedValues, insertedValues}) =>
    focusedElement = document.activeElement if @hasFocus()
    @onChildRemoved(child, index) for child in removedValues
    @onChildAdded(child, index + i) for child, i in insertedValues
    focusedElement?.focus() if document.activeElement is document.body

  onChildAdded: (child, index) =>
    view = atom.views.findOrCreate(child)
    @insertAt(index, view)

  onChildRemoved: (child) =>
    view = atom.views.find(child)
    view.detach()
    PaneView ?= require './pane-view'

    if view instanceof PaneView and view.model.isDestroyed()
      @getContainer()?.trigger 'pane:removed', [view]

  getContainer: ->
    @closest('.panes').view()
