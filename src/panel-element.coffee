{CompositeDisposable} = require 'event-kit'
{callAttachHooks} = require './space-pen-extensions'

class PanelElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  initialize: (@model) ->
    @appendChild(@getItemView())

    @classList.add(@model.getClassName().split(' ')...) if @model.getClassName()?
    @subscriptions.add @model.onDidChangeVisible(@visibleChanged.bind(this))
    @subscriptions.add @model.onDidDestroy(@destroyed.bind(this))
    this

  getModel: -> @model

  getItemView: ->
    atom.views.getView(@model.getItem())

  attachedCallback: ->
    callAttachHooks(@getItemView()) # for backward compatibility with SpacePen views
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
