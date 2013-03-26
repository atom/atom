TextMateGrammar = require 'text-mate-grammar'
Package = require 'package'
fsUtils = require 'fs-utils'
_ = require 'underscore'
$ = require 'jquery'
CSON = require 'cson'

module.exports =
class AtomPackage extends Package
  metadata: null
  keymaps: null
  stylesheets: null
  grammars: null
  mainModulePath: null
  resolvedMainModulePath: false
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

  activate: ({immediate}={}) ->
    keymap.add(map) for map in @keymaps
    applyStylesheet(path, content) for [path, content] in @stylesheets
    syntax.addGrammar(grammar) for grammar in @grammars

    if @deferActivation and not immediate
      @subscribeToActivationEvents()
    else
      @activateNow()

  activateNow: ->
    try
      if @requireMainModule()
        config.setDefaults(@name, @mainModule.configDefaults)
        @mainModule.activate(atom.getPackageState(@name) ? {})
    catch e
      console.warn "Failed to activate package named '#{@name}'", e.stack

  loadMetadata: ->
    if metadataPath = fsUtils.resolveExtension(fsUtils.join(@path, 'package'), ['cson', 'json'])
      @metadata = CSON.readObject(metadataPath)
    @metadata ?= {}

  loadKeymaps: ->
    @keymaps = []

    keymapsDirPath = fsUtils.join(@path, 'keymaps')
    keymapExtensions = ['cson', 'json', '']

    if @metadata.keymaps
      for path in @metadata.keymaps
        @keymaps.push(CSON.readObject(fsUtils.resolve(keymapsDirPath, path, keymapExtensions)))
    else
      for path in fsUtils.list(keymapsDirPath, ['cson', 'json', '']) ? []
        @keymaps.push(CSON.readObject(path))

  loadStylesheets: ->
    @stylesheets = []
    @stylesheets.push([path, loadStylesheet(path)]) for path in @getStylesheetPaths()

  getStylesheetPaths: ->
    stylesheetDirPath = fsUtils.join(@path, 'stylesheets')
    if @metadata.stylesheets
      @metadata.stylesheets.map (name) -> fsUtils.resolve(stylesheetDirPath, name, ['css', 'less', ''])
    else
      fsUtils.list(stylesheetDirPath, ['css', 'less']) ? []

  loadGrammars: ->
    @grammars = []
    grammarsDirPath = fsUtils.join(@path, 'grammars')
    for grammarPath in fsUtils.list(grammarsDirPath, ['.cson', '.json']) ? []
      @grammars.push(TextMateGrammar.loadSync(grammarPath))

  loadScopedProperties: ->
    scopedPropertiessDirPath = fsUtils.join(@path, 'scoped-properties')
    for scopedPropertiesPath in fsUtils.list(scopedPropertiessDirPath, ['.cson', '.json']) ? []
      for selector, properties of fsUtils.readObject(scopedPropertiesPath)
        syntax.addProperties(selector, properties)

  serialize: ->
    try
      @mainModule?.serialize?()
    catch e
      console.error "Error serializing package '#{@name}'", e.stack

  deactivate: ->
    syntax.removeGrammar(grammar) for grammar in @grammars
    @mainModule?.deactivate?()

  requireMainModule: ->
    return @mainModule if @mainModule
    mainModulePath = @getMainModulePath()
    @mainModule = require(mainModulePath) if fsUtils.isFile(mainModulePath)

  getMainModulePath: ->
    return @mainModulePath if @resolvedMainModulePath
    @resolvedMainModulePath = true
    mainModulePath =
      if @metadata.main
        fsUtils.join(@path, @metadata.main)
      else
        fsUtils.join(@path, 'index')
    @mainModulePath = fsUtils.resolveExtension(mainModulePath, ["", _.keys(require.extensions)...])

  registerDeferredDeserializers: ->
    for deserializerName in @metadata.deferredDeserializers ? []
      registerDeferredDeserializer deserializerName, => @requireMainModule()

  subscribeToActivationEvents: () ->
    return unless @metadata.activationEvents?

    activateHandler = (event) =>
      bubblePathEventHandlers = @disableEventHandlersOnBubblePath(event)
      @deferActivation = false
      @activateNow()
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
