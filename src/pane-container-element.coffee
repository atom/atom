{CompositeDisposable} = require 'event-kit'
_ = require 'underscore-plus'

module.exports =
class PaneContainerElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @classList.add 'panes'

  initialize: (@model, {@views}) ->
    throw new Error("Must pass a views parameter when initializing PaneContainerElements") unless @views?

    @subscriptions.add @model.observeRoot(@rootChanged.bind(this))
    this

  rootChanged: (root) ->
    focusedElement = document.activeElement if @hasFocus()
    @firstChild?.remove()
    if root?
      view = @views.getView(root)
      @appendChild(view)
      focusedElement?.focus()

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)


module.exports = PaneContainerElement = document.registerElement 'atom-pane-container', prototype: PaneContainerElement.prototype
