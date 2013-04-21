TextMateGrammar = require 'text-mate-grammar'
Package = require 'package'
fsUtils = require 'fs-utils'
_ = require 'underscore'
$ = require 'jquery'
CSON = require 'cson'


###
# Internal: Loads and resolves packages. #
###

module.exports =
class AtomPackage extends Package
  metadata: null
  keymaps: null
  stylesheets: null
  grammars: null
  scopedProperties: null
  mainModulePath: null
  resolvedMainModulePath: false
  mainModule: null

  load: ->
    try
      @loadMetadata()
      @loadKeymaps()
      @loadStylesheets()
      @loadGrammars()
      @loadScopedProperties()
      if @metadata.activationEvents?
        @registerDeferredDeserializers()
      else
        @requireMainModule()
    catch e
      console.warn "Failed to load package named '#{@name}'", e.stack ? e
    this

  activate: ({immediate}={}) ->
    keymap.add(path, map) for [path, map] in @keymaps
    applyStylesheet(path, content) for [path, content] in @stylesheets
    syntax.addGrammar(grammar) for grammar in @grammars
    syntax.addProperties(path, selector, properties) for [path, selector, properties] in @scopedProperties

    if @metadata.activationEvents? and not immediate
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
    @keymaps = @getKeymapPaths().map (path) -> [path, CSON.readObject(path)]

  getKeymapPaths: ->
    keymapsDirPath = fsUtils.join(@path, 'keymaps')
    if @metadata.keymaps
      @metadata.keymaps.map (name) -> fsUtils.resolve(keymapsDirPath, name, ['cson', 'json', ''])
    else
      fsUtils.list(keymapsDirPath, ['cson', 'json']) ? []

  loadStylesheets: ->
    @stylesheets = @getStylesheetPaths().map (path) -> [path, loadStylesheet(path)]

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
    @scopedProperties = []
    scopedPropertiessDirPath = fsUtils.join(@path, 'scoped-properties')
    for scopedPropertiesPath in fsUtils.list(scopedPropertiessDirPath, ['.cson', '.json']) ? []
      for selector, properties of fsUtils.readObject(scopedPropertiesPath)
        @scopedProperties.push([scopedPropertiesPath, selector, properties])

  serialize: ->
    try
      @mainModule?.serialize?()
    catch e
      console.error "Error serializing package '#{@name}'", e.stack

  deactivate: ->
    @unsubscribeFromActivationEvents()
    syntax.removeGrammar(grammar) for grammar in @grammars
    syntax.removeProperties(path) for [path] in @scopedProperties
    keymap.remove(path) for [path] in @keymaps
    removeStylesheet(path) for [path] in @stylesheets
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
    if _.isArray(@metadata.activationEvents)
      rootView.command(event, @handleActivationEvent) for event in @metadata.activationEvents
    else
      rootView.command(event, selector, @handleActivationEvent) for event, selector of @metadata.activationEvents

  handleActivationEvent: (event) =>
    bubblePathEventHandlers = @disableEventHandlersOnBubblePath(event)
    @activateNow()
    $(event.target).trigger(event)
    @restoreEventHandlersOnBubblePath(bubblePathEventHandlers)
    @unsubscribeFromActivationEvents()

  unsubscribeFromActivationEvents: ->
    if _.isArray(@metadata.activationEvents)
      rootView.off(event, @handleActivationEvent) for event in @metadata.activationEvents
    else
      rootView.off(event, selector, @handleActivationEvent) for event, selector of @metadata.activationEvents

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
