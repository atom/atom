{Emitter, Disposable} = require 'event-kit'

module.exports =
class StyleManager
  constructor: ->
    @emitter = new Emitter
    @styleElements = []
    @styleElementsBySourcePath = {}

  observeStyleElements: (callback) ->
    callback(styleElement) for styleElement in @getStyleElements()
    @onDidAddStyleElement(callback)

  onDidAddStyleElement: (callback) ->
    @emitter.on 'did-add-style-element', callback

  onDidRemoveStyleElement: (callback) ->
    @emitter.on 'did-remove-style-element', callback

  onDidUpdateStyleElement: (callback) ->
    @emitter.on 'did-update-style-element', callback

  getStyleElements: ->
    @styleElements.slice()

  addStyleSheet: (source, params) ->
    sourcePath = params?.sourcePath
    group = params?.group

    if sourcePath? and styleElement = @styleElementsBySourcePath[sourcePath]
      updated = true
    else
      styleElement = document.createElement('style')
      styleElement.sourcePath = sourcePath if sourcePath?
      styleElement.group = group if group?

    styleElement.textContent = source

    if group?
      for existingElement, index in @styleElements
        if existingElement.group is group
          insertIndex = index + 1
        else
          break if insertIndex?
    insertIndex ?= @styleElements.length

    @styleElements.splice(insertIndex, 0, styleElement)
    @styleElementsBySourcePath[sourcePath] ?= styleElement if sourcePath?

    if updated
      @emitter.emit 'did-update-style-element', styleElement
    else
      @emitter.emit 'did-add-style-element', styleElement

    new Disposable => @removeStyleElement(styleElement, params)

  removeStyleElement: (styleElement, params) ->
    index = @styleElements.indexOf(styleElement)
    unless index is -1
      @styleElements.splice(index, 1)
      sourcePath = params?.sourcePath
      delete @styleElementsBySourcePath[sourcePath] if sourcePath?
      @emitter.emit 'did-remove-style-element', styleElement

  clear: ->
    @styleElements = []
    @styleElementsBySourcePath = {}
