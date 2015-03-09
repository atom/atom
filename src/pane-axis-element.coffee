{CompositeDisposable} = require 'event-kit'
{callAttachHooks} = require './space-pen-extensions'
PaneResizeHandleView = require './pane-resize-handle-view'

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

  isPaneResizeHandleElement: (element) ->
    element?.classList.contains('pane-resize-handle')

  childAdded: ({child, index}) ->
    view = atom.views.getView(child)
    @insertBefore(view, @children[index * 2])

    prevElement = view.previousSibling
    # if previous element is not pane resize element, then insert new resize element
    if prevElement? and not @isPaneResizeHandleElement(prevElement)
      resizeView = new PaneResizeHandleView()
      resizeView.initialize()
      @insertBefore(resizeView[0], view)

    nextElement = view.nextSibling
    # if next element isnot resize element, then insert new resize element
    if nextElement? and not @isPaneResizeHandleElement(nextElement)
      resizeView = new PaneResizeHandleView()
      resizeView.initialize()
      @insertBefore(resizeView[0], nextElement)

    callAttachHooks(view) # for backward compatibility with SpacePen views

  childRemoved: ({child}) ->
    view = atom.views.getView(child)
    siblingView = view.previousSibling
    # make sure next sibling view is pane resize view
    if siblingView?.classList.contains('pane-resize-handle')
      siblingView.remove()
    view.remove()

  childReplaced:  ({index, oldChild, newChild}) ->
    focusedElement = document.activeElement if @hasFocus()
    @childRemoved({child: oldChild, index})
    @childAdded({child: newChild, index})
    focusedElement?.focus() if document.activeElement is document.body

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

module.exports = PaneAxisElement = document.registerElement 'atom-pane-axis', prototype: PaneAxisElement.prototype
