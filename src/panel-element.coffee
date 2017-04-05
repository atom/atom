{CompositeDisposable} = require 'event-kit'
Panel = require './panel'

class PanelElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  initialize: (@model, @viewRegistry) ->
    @appendChild(@getItemView())

    @classList.add(@model.getClassName().split(' ')...) if @model.getClassName()?
    @subscriptions.add @model.onDidChangeVisible(@visibleChanged.bind(this))
    @subscriptions.add @model.onDidDestroy(@destroyed.bind(this))
    this

  getModel: -> @model

  getItemView: ->
    @viewRegistry.getView(@getModel().getItem())

  attachedCallback: ->
    @visibleChanged(@getModel().isVisible())

  visibleChanged: (visible) ->
    if visible
      @style.display = null
    else
      @style.display = 'none'

  destroyed: ->
    @subscriptions.dispose()
    @remove()

module.exports = PanelElement = document.registerElement 'atom-panel', prototype: PanelElement.prototype
