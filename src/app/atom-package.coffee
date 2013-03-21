TextMateGrammar = require 'text-mate-grammar'
Package = require 'package'
fs = require 'fs-utils'
_ = require 'underscore'
$ = require 'jquery'
CSON = require 'cson'

module.exports =
class AtomPackage extends Package
  metadata: null
  mainModule: null
  deferActivation: false

  load: ->
    try
      @loadMetadata()
      @loadKeymaps()
      @loadStylesheets()
      @loadGrammars()
      @loadScopedProperties()
      if @deferActivation = @metadata.activationEvents?
        @registerDeferredDeserializers()
      else
        @requireMainModule()
    catch e
      console.warn "Failed to load package named '#{@name}'", e.stack
    this

  loadMetadata: ->
    if metadataPath = fs.resolveExtension(fs.join(@path, 'package'), ['cson', 'json'])
      @metadata = CSON.readObject(metadataPath)
    @metadata ?= {}

  loadKeymaps: ->
    keymapsDirPath = fs.join(@path, 'keymaps')

    if @metadata.keymaps
      for path in @metadata.keymaps
        keymapPath = fs.resolve(keymapsDirPath, path, ['cson', 'json', ''])
        keymap.load(keymapPath)
    else
      keymap.loadDirectory(keymapsDirPath)

  loadStylesheets: ->
    stylesheetDirPath = fs.join(@path, 'stylesheets')
    for stylesheetPath in fs.list(stylesheetDirPath)
      requireStylesheet(stylesheetPath)

  loadGrammars: ->
    grammarsDirPath = fs.join(@path, 'grammars')
    for grammarPath in fs.list(grammarsDirPath, ['.cson', '.json'])
      grammarContent = fs.readObject(grammarPath)
      grammar = new TextMateGrammar(grammarContent)
      syntax.addGrammar(grammar)

  loadScopedProperties: ->
    scopedPropertiessDirPath = fs.join(@path, 'scoped-properties')
    for scopedPropertiesPath in fs.list(scopedPropertiessDirPath, ['.cson', '.json'])
      for selector, properties of fs.readObject(scopedPropertiesPath)
        syntax.addProperties(selector, properties)

  activate: ->
    if @deferActivation
      @subscribeToActivationEvents()
    else
      try
        if @requireMainModule()
          config.setDefaults(@name, @mainModule.configDefaults)
          atom.activateAtomPackage(this)
      catch e
        console.warn "Failed to activate package named '#{@name}'", e.stack

  requireMainModule: ->
    return @mainModule if @mainModule
    mainPath =
      if @metadata.main
        fs.join(@path, @metadata.main)
      else
        fs.join(@path, 'index')
    mainPath = fs.resolveExtension(mainPath, ["", _.keys(require.extensions)...])
    @mainModule = require(mainPath) if fs.isFile(mainPath)

  registerDeferredDeserializers: ->
    for deserializerName in @metadata.deferredDeserializers ? []
      registerDeferredDeserializer deserializerName, => @requireMainModule()

  subscribeToActivationEvents: () ->
    return unless @metadata.activationEvents?

    activateHandler = (event) =>
      bubblePathEventHandlers = @disableEventHandlersOnBubblePath(event)
      @deferActivation = false
      @activate()
      $(event.target).trigger(event)
      @restoreEventHandlersOnBubblePath(bubblePathEventHandlers)
      @unsubscribeFromActivationEvents(activateHandler)

    if _.isArray(@metadata.activationEvents)
      rootView.command(event, activateHandler) for event in @metadata.activationEvents
    else
      rootView.command(event, selector, activateHandler) for event, selector of @metadata.activationEvents

  unsubscribeFromActivationEvents: (activateHandler) ->
    if _.isArray(@metadata.activationEvents)
      rootView.off(event, activateHandler) for event in @metadata.activationEvents
    else
      rootView.off(event, selector, activateHandler) for event, selector of @metadata.activationEvents

  disableEventHandlersOnBubblePath: (event) ->
    bubblePathEventHandlers = []
    disabledHandler = ->
    element = $(event.target)
    while element.length
      if eventHandlers = element.data('events')?[event.type]
        for eventHandler in eventHandlers
          eventHandler.disabledHandler = eventHandler.handler
          eventHandler.handler = disabledHandler
          bubblePathEventHandlers.push(eventHandler)
      element = element.parent()
    bubblePathEventHandlers

  restoreEventHandlersOnBubblePath: (eventHandlers) ->
    for eventHandler in eventHandlers
      eventHandler.handler = eventHandler.disabledHandler
      delete eventHandler.disabledHandler
