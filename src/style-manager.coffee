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
      styleElement.setAttribute('source-path', sourcePath) if sourcePath?
      styleElement.setAttribute('group', group) if group?

    styleElement.textContent = source

    if updated
      @emitter.emit 'did-update-style-element', styleElement
    else
      @addStyleElement(styleElement, params)

    new Disposable => @removeStyleElement(styleElement)

  addStyleElement: (styleElement, params) ->
    sourcePath = params?.sourcePath
    group = params?.group

    if group?
      for existingElement, index in @styleElements
        if existingElement.getAttribute('group') is group
          insertIndex = index + 1
        else
          break if insertIndex?
    insertIndex ?= @styleElements.length

    @styleElements.splice(insertIndex, 0, styleElement)
    @styleElementsBySourcePath[sourcePath] ?= styleElement if sourcePath?
    @emitter.emit 'did-add-style-element', styleElement

  removeStyleElement: (styleElement, params) ->
    index = @styleElements.indexOf(styleElement)
    unless index is -1
      @styleElements.splice(index, 1)
      if sourcePath = styleElement.getAttribute('source-path')
        delete @styleElementsBySourcePath[sourcePath]
      @emitter.emit 'did-remove-style-element', styleElement

  getSnapshot: ->
    @styleElements.slice()

  restoreSnapshot: (styleElementsToRestore) ->
    for styleElement in @getStyleElements()
      @removeStyleElement(styleElement) unless styleElement in styleElementsToRestore

    existingStyleElements = @getStyleElements()
    for styleElement in styleElementsToRestore
      unless styleElement in existingStyleElements
        sourcePath = styleElement.getAttribute('source-path')
        group = styleElement.getAttribute('group')
        @addStyleElement(styleElement, {sourcePath, group})
