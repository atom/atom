{CompositeDisposable} = require 'event-kit'

class PanelContainerElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  getModel: -> @model

  setModel: (@model) ->
    @subscriptions.add @model.onDidAddPanel(@panelAdded.bind(this))
    @subscriptions.add @model.onDidRemovePanel(@panelRemoved.bind(this))
    @subscriptions.add @model.onDidDestroy(@destroyed.bind(this))

  panelAdded: ({panel, index}) ->
    panelElement = panel.getView()
    panelElement.setAttribute('location', @model.getLocation())
    if index >= @childNodes.length
      @appendChild(panelElement)
    else
      referenceItem = @childNodes[index + 1]
      @insertBefore(panelElement, referenceItem)

  panelRemoved: ({panel, index}) ->
    @removeChild(@childNodes[index])

  destroyed: ->
    @subscriptions.dispose()
    @parentNode?.removeChild(this)

module.exports = PanelContainerElement = document.registerElement 'atom-panel-container', prototype: PanelContainerElement.prototype
