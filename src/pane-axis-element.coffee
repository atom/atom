{CompositeDisposable} = require 'event-kit'
PaneResizeHandleElement = require './pane-resize-handle-element'

class PaneAxisElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  detachedCallback: ->
    @subscriptions.dispose()

  initialize: (@model, {@views}) ->
    throw new Error("Must pass a views parameter when initializing TextEditorElements") unless @views?

    @subscriptions.add @model.onDidAddChild(@childAdded.bind(this))
    @subscriptions.add @model.onDidRemoveChild(@childRemoved.bind(this))
    @subscriptions.add @model.onDidReplaceChild(@childReplaced.bind(this))
    @subscriptions.add @model.observeFlexScale(@flexScaleChanged.bind(this))

    @childAdded({child, index}) for child, index in @model.getChildren()

    switch @model.getOrientation()
      when 'horizontal'
        @classList.add('horizontal', 'pane-row')
      when 'vertical'
        @classList.add('vertical', 'pane-column')
    this

  isPaneResizeHandleElement: (element) ->
    element?.nodeName.toLowerCase() is 'atom-pane-resize-handle'

  childAdded: ({child, index}) ->
    view = @views.getView(child)
    @insertBefore(view, @children[index * 2])

    prevElement = view.previousSibling
    # if previous element is not pane resize element, then insert new resize element
    if prevElement? and not @isPaneResizeHandleElement(prevElement)
      resizeHandle = document.createElement('atom-pane-resize-handle')
      @insertBefore(resizeHandle, view)

    nextElement = view.nextSibling
    # if next element isnot resize element, then insert new resize element
    if nextElement? and not @isPaneResizeHandleElement(nextElement)
      resizeHandle = document.createElement('atom-pane-resize-handle')
      @insertBefore(resizeHandle, nextElement)

  childRemoved: ({child}) ->
    view = @views.getView(child)
    siblingView = view.previousSibling
    # make sure next sibling view is pane resize view
    if siblingView? and @isPaneResizeHandleElement(siblingView)
      siblingView.remove()
    view.remove()

  childReplaced: ({index, oldChild, newChild}) ->
    focusedElement = document.activeElement if @hasFocus()
    @childRemoved({child: oldChild, index})
    @childAdded({child: newChild, index})
    focusedElement?.focus() if document.activeElement is document.body

  flexScaleChanged: (flexScale) -> @style.flexGrow = flexScale

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

module.exports = PaneAxisElement = document.registerElement 'atom-pane-axis', prototype: PaneAxisElement.prototype
