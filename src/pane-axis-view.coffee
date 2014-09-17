{CompositeDisposable} = require 'event-kit'
{View} = require './space-pen-extensions'
PaneView = null

module.exports =
class PaneAxisView extends View
  initialize: (@model) ->
    @subscriptions = new CompositeDisposable

    @onChildAdded({child, index}) for child, index in @model.getChildren()

    @subscriptions.add @model.onDidAddChild(@onChildAdded)
    @subscriptions.add @model.onDidRemoveChild(@onChildRemoved)
    @subscriptions.add @model.onDidReplaceChild(@onChildReplaced)

  afterAttach: ->
    @container = @closest('.panes').view()

  onChildReplaced:  ({index, oldChild, newChild}) =>
    focusedElement = document.activeElement if @hasFocus()
    @onChildRemoved({child: oldChild, index})
    @onChildAdded({child: newChild, index})
    focusedElement?.focus() if document.activeElement is document.body

  onChildAdded: ({child, index}) =>
    view = @model.getView(child).__spacePenView
    @insertAt(index, view)

  onChildRemoved: ({child}) =>
    view = @model.getView(child).__spacePenView
    view.detach()
    PaneView ?= require './pane-view'
    if view instanceof PaneView and view.model.isDestroyed()
      @container?.trigger 'pane:removed', [view]

  beforeRemove: ->
    @subscriptions.dispose()
