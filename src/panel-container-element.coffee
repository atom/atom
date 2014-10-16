{CompositeDisposable} = require 'event-kit'

class PanelContainerElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  getModel: -> @model

  setModel: (@model) ->
    @subscriptions.add @model.onDidAddPanel(@panelAdded.bind(this))
    @subscriptions.add @model.onDidRemovePanel(@panelRemoved.bind(this))
    @subscriptions.add @model.onDidDestroy(@destroyed.bind(this))

    @setAttribute('location', @model.getLocation())

  panelAdded: ({panel, index}) ->
    if index >= @childNodes.length
      @appendChild(panel.getView())
    else
      referenceItem = @childNodes[index + 1]
      @insertBefore(panel.getView(), referenceItem)

  panelRemoved: ({panel, index}) ->
    @removeChild(@childNodes[index])

  destroyed: ->
    @subscriptions.dispose()
    @parentNode?.removeChild(this)

module.exports = PanelContainerElement = document.registerElement 'atom-panel-container', prototype: PanelContainerElement.prototype
