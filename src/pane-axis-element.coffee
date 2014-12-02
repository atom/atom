{CompositeDisposable} = require 'event-kit'
{callAttachHooks} = require './space-pen-extensions'

class PaneAxisElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  detachedCallback: ->
    @subscriptions.dispose()

  initialize: (@model) ->
    @subscriptions.add @model.onDidAddChild(@childAdded.bind(this))
    @subscriptions.add @model.onDidRemoveChild(@childRemoved.bind(this))
    @subscriptions.add @model.onDidReplaceChild(@childReplaced.bind(this))

    @childAdded({child, index}) for child, index in @model.getChildren()

    switch @model.getOrientation()
      when 'horizontal'
        @classList.add('horizontal', 'pane-row')
      when 'vertical'
        @classList.add('vertical', 'pane-column')
    this

  childAdded: ({child, index}) ->
    view = atom.views.getView(child)
    @insertBefore(view, @children[index])
    callAttachHooks(view) # for backward compatibility with SpacePen views

  childRemoved: ({child}) ->
    view = atom.views.getView(child)
    view.remove()

  childReplaced:  ({index, oldChild, newChild}) ->
    focusedElement = document.activeElement if @hasFocus()
    @childRemoved({child: oldChild, index})
    @childAdded({child: newChild, index})
    focusedElement?.focus() if document.activeElement is document.body

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

module.exports = PaneAxisElement = document.registerElement 'atom-pane-axis', prototype: PaneAxisElement.prototype
