{Emitter, Disposable} = require 'event-kit'

module.exports =
class StyleManager
  constructor: ->
    @emitter = new Emitter
    @styleElements = []
    @styleElementsBySourcePath = {}

  onDidAddStyleSheet: (callback) ->
    @emitter.on 'did-add-style-sheet', callback

  onDidRemoveStyleSheet: (callback) ->
    @emitter.on 'did-remove-style-sheet', callback

  onDidUpdateStyleSheet: (callback) ->
    @emitter.on 'did-update-style-sheet', callback

  getStyleElements: ->
    @styleElements.slice()

  addStyleSheet: (source, params) ->
    sourcePath = params?.sourcePath
    group = params?.group

    if sourcePath? and styleElement = @styleElementsBySourcePath[sourcePath]
      updated = true
    else
      styleElement = document.createElement('style')
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
      @emitter.emit 'did-update-style-sheet', {styleElement, sourcePath, group}
    else
      @emitter.emit 'did-add-style-sheet', {styleElement, sourcePath, group}

    new Disposable => @removeStyleElement(styleElement, params)

  removeStyleElement: (styleElement, params) ->
    index = @styleElements.indexOf(styleElement)
    unless index is -1
      @styleElements.splice(index, 1)
      sourcePath = params?.sourcePath
      delete @styleElementsBySourcePath[sourcePath] if sourcePath?
      @emitter.emit 'did-remove-style-sheet', {styleElement}
