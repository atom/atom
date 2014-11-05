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
    context = params?.context
    group = params?.group

    if sourcePath? and styleElement = @styleElementsBySourcePath[sourcePath]
      updated = true
    else
      styleElement = document.createElement('style')
      if sourcePath?
        styleElement.sourcePath = sourcePath
        styleElement.setAttribute('source-path', sourcePath)

      if context?
        styleElement.context = context
        styleElement.setAttribute('context', context)

      if group?
        styleElement.group = group
        styleElement.setAttribute('group', group)

    styleElement.textContent = source

    if updated
      @emitter.emit 'did-update-style-element', styleElement
    else
      @addStyleElement(styleElement)

    new Disposable => @removeStyleElement(styleElement)

  addStyleElement: (styleElement) ->
    {sourcePath, group} = styleElement

    if group?
      for existingElement, index in @styleElements
        if existingElement.group is group
          insertIndex = index + 1
        else
          break if insertIndex?
    insertIndex ?= @styleElements.length

    @styleElements.splice(insertIndex, 0, styleElement)
    @styleElementsBySourcePath[sourcePath] ?= styleElement if sourcePath?
    @emitter.emit 'did-add-style-element', styleElement

  removeStyleElement: (styleElement) ->
    index = @styleElements.indexOf(styleElement)
    unless index is -1
      @styleElements.splice(index, 1)
      delete @styleElementsBySourcePath[styleElement.sourcePath] if styleElement.sourcePath?
      @emitter.emit 'did-remove-style-element', styleElement

  getSnapshot: ->
    @styleElements.slice()

  restoreSnapshot: (styleElementsToRestore) ->
    for styleElement in @getStyleElements()
      @removeStyleElement(styleElement) unless styleElement in styleElementsToRestore

    existingStyleElements = @getStyleElements()
    for styleElement in styleElementsToRestore
      @addStyleElement(styleElement) unless styleElement in existingStyleElements
