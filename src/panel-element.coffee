{CompositeDisposable} = require 'event-kit'
{callAttachHooks} = require './space-pen-extensions'

class PanelElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  getModel: -> @model

  setModel: (@model) ->
    view = @model.getItemView()
    @appendChild(view)
    callAttachHooks(view) # for backward compatibility with SpacePen views

    @subscriptions.add @model.onDidChangeVisible(@visibleChanged.bind(this))
    @subscriptions.add @model.onDidDestroy(@destroyed.bind(this))

  attachedCallback: ->
    @visibleChanged(@model.isVisible())

  visibleChanged: (visible) ->
    if visible
      @style.display = null
    else
      @style.display = 'none'

  destroyed: ->
    @subscriptions.dispose()
    @parentNode?.removeChild(this)

module.exports = PanelElement = document.registerElement 'atom-panel', prototype: PanelElement.prototype
