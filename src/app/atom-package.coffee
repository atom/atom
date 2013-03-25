TextMateGrammar = require 'text-mate-grammar'
Package = require 'package'
fs = require 'fs-utils'
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

  loadMetadata: ->
    if metadataPath = fs.resolveExtension(fs.join(@path, 'package'), ['cson', 'json'])
      @metadata = CSON.readObject(metadataPath)
    @metadata ?= {}

  loadKeymaps: ->
    @keymaps = []

    keymapsDirPath = fs.join(@path, 'keymaps')
    keymapExtensions = ['cson', 'json', '']

    if @metadata.keymaps
      for path in @metadata.keymaps
        @keymaps.push(CSON.readObject(fs.resolve(keymapsDirPath, path, keymapExtensions)))
    else
      for path in fs.list(keymapsDirPath, ['cson', 'json', '']) ? []
        @keymaps.push(CSON.readObject(path))

  loadStylesheets: ->
    @stylesheets = []
    stylesheetDirPath = fs.join(@path, 'stylesheets')
    for stylesheetPath in fs.list(stylesheetDirPath, ['css', 'less']) ? []
      @stylesheets.push([stylesheetPath, loadStylesheet(stylesheetPath)])

  loadGrammars: ->
    @grammars = []
    grammarsDirPath = fs.join(@path, 'grammars')
    for grammarPath in fs.list(grammarsDirPath, ['.cson', '.json']) ? []
      @grammars.push(TextMateGrammar.loadSync(grammarPath))

  loadScopedProperties: ->
    scopedPropertiessDirPath = fs.join(@path, 'scoped-properties')
    for scopedPropertiesPath in fs.list(scopedPropertiessDirPath, ['.cson', '.json']) ? []
      for selector, properties of fs.readObject(scopedPropertiesPath)
        syntax.addProperties(selector, properties)

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

  serialize: ->
    try
      @mainModule?.serialize?()
    catch e
      console.error "Error serializing package '#{@name}'", e.stack

  deactivate: ->
    @mainModule?.deactivate?()

  requireMainModule: ->
    return @mainModule if @mainModule
    mainModulePath = @getMainModulePath()
    @mainModule = require(mainModulePath) if fs.isFile(mainModulePath)

  getMainModulePath: ->
    return @mainModulePath if @resolvedMainModulePath
    @resolvedMainModulePath = true
    mainModulePath =
      if @metadata.main
        fs.join(@path, @metadata.main)
      else
        fs.join(@path, 'index')
    @mainModulePath = fs.resolveExtension(mainModulePath, ["", _.keys(require.extensions)...])

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
