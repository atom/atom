Serializable = require 'serializable'
{$, View} = require './space-pen-extensions'
PaneAxisModel = require './pane-axis-model'
Pane = null

### Internal ###
module.exports =
class PaneAxis extends View
  initialize: (@model) ->
    @subscribe @model.children.onRemoval @onChildRemoved
    @subscribe @model.children.onEach @onChildAdded

    @onChildAdded(child) for child in children ? []

  viewForModel: (model) ->
    viewClass = model.getViewClass()
    model._view ?= new viewClass(model)

  addChild: (child, index) ->
    @model.addChild(child.model, index)

  removeChild: (child) ->
    @model.removeChild(child.model)

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
