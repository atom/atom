{CompositeDisposable} = require 'event-kit'
Panel = require './panel'

class PanelElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  initialize: (@model, {@views}) ->
    throw new Error("Must pass a views parameter when initializing PanelElements") unless @views?

    @appendChild(@getItemView())

    @classList.add(@model.getClassName().split(' ')...) if @model.getClassName()?
    @subscriptions.add @model.onDidChangeVisible(@visibleChanged.bind(this))
    @subscriptions.add @model.onDidDestroy(@destroyed.bind(this))
    @subscriptions.add window.onresize = @updateModalSize
    this
  
  updateModalSize: ->
    modalPanels = atom.views.getView(atom.workspace).panelContainers.modal.children
    screenWidth = atom.getSize().width
    fontSize = atom.config.get('editor.fontSize')
    screenEM = screenWidth/fontSize
    for a in modalPanels
      if screenEM < 50
        a.style.width = "#{screenEM}em"
        marginLeftNew = screenEM/2
        a.style.marginLeft = "-#{marginLeftNew}em"
      else
        a.style.width = "50em"
        a.style.marginLeft = "-25em"

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

module.exports = PanelElement = document.registerElement 'atom-panel', prototype: PanelElement.prototype
