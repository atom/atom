{CompositeDisposable} = require 'event-kit'
Panel = require './panel'

module.exports =
class PanelElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  initialize: (@model, {@views}) ->
    throw new Error("Must pass a views parameter when initializing PanelElements") unless @views?

    @appendChild(@getItemView())

    @classList.add(@model.getClassName().split(' ')...) if @model.getClassName()?
    @subscriptions.add @model.onDidChangeVisible(@visibleChanged.bind(this))
    @subscriptions.add @model.onDidDestroy(@destroyed.bind(this))
    this

  getModel: ->
    @model ?= new Panel

  getItemView: ->
    @views.getView(@getModel().getItem())

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
