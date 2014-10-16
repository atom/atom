{CompositeDisposable} = require 'event-kit'

class PanelElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable

  getModel: -> @model

  setModel: (@model) ->
    @appendChild(@model.getItemView())
    @subscriptions.add @model.onDidDestroy(@destroyed.bind(this))

  destroyed: ->
    @subscriptions.dispose()
    @parentNode?.removeChild(this)

module.exports = PanelElement = document.registerElement 'atom-panel', prototype: PanelElement.prototype
