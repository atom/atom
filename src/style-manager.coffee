{Emitter, Disposable} = require 'event-kit'

module.exports =
class StyleManager
  constructor: ->
    @emitter = new Emitter
    @styleElements = []

  onDidAddStyleSheet: (callback) ->
    @emitter.on 'did-add-style-sheet', callback

  onDidRemoveStyleSheet: (callback) ->
    @emitter.on 'did-remove-style-sheet', callback

  getStyleElements: ->
    @styleElements.slice()

  addStyleSheet: (source) ->
    styleElement = document.createElement('style')
    styleElement.textContent = source
    @styleElements.push(styleElement)
    @emitter.emit 'did-add-style-sheet', {styleElement}

    new Disposable => @removeStyleElement(styleElement)

  removeStyleElement: (styleElement) ->
    index = @styleElements.indexOf(styleElement)
    unless index is -1
      @styleElements.splice(index, 1)
      @emitter.emit 'did-remove-style-sheet', {styleElement}
