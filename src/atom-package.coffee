TextMateGrammar = require 'text-mate-grammar'
Package = require 'package'
fsUtils = require 'fs-utils'
path = require 'path'
_ = require 'underscore'
$ = require 'jquery'
CSON = require 'season'
EventEmitter = require 'event-emitter'

### Internal: Loads and resolves packages. ###

module.exports =
class AtomPackage extends Package
  _.extend @prototype, EventEmitter

  @stylesheetsDir: 'stylesheets'

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
      @metadata = Package.loadMetadata(@path)
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
    @activateResources()
    if @metadata.activationEvents? and not immediate
      @subscribeToActivationEvents()
    else
      @activateNow()

  activateNow: ->
    try
      @activateConfig()
      if @requireMainModule()
        @mainModule.activate(atom.getPackageState(@name) ? {})
        @mainActivated = true
    catch e
      console.warn "Failed to activate package named '#{@name}'", e.stack

  activateConfig: ->
    return if @configActivated

    @requireMainModule()
    if @mainModule?
      config.setDefaults(@name, @mainModule.configDefaults)
      @mainModule.activateConfig?()
    @configActivated = true

  activateResources: ->
    keymap.add(keymapPath, map) for [keymapPath, map] in @keymaps
    type = if @metadata.theme then 'theme' else 'bundled'
    applyStylesheet(stylesheetPath, content, type) for [stylesheetPath, content] in @stylesheets
    syntax.addGrammar(grammar) for grammar in @grammars
    for [scopedPropertiesPath, selector, properties] in @scopedProperties
      syntax.addProperties(scopedPropertiesPath, selector, properties)

  loadKeymaps: ->
    @keymaps = @getKeymapPaths().map (keymapPath) -> [keymapPath, CSON.readFileSync(keymapPath)]

  getKeymapPaths: ->
    keymapsDirPath = path.join(@path, 'keymaps')
    if @metadata.keymaps
      @metadata.keymaps.map (name) -> fsUtils.resolve(keymapsDirPath, name, ['json', 'cson', ''])
    else
      fsUtils.listSync(keymapsDirPath, ['cson', 'json'])

  loadStylesheets: ->
    @stylesheets = @getStylesheetPaths().map (stylesheetPath) -> [stylesheetPath, loadStylesheet(stylesheetPath)]

  getStylesheetsPath: ->
    path.join(@path, @constructor.stylesheetsDir)

  getStylesheetPaths: ->
    stylesheetDirPath = @getStylesheetsPath()

    if @metadata.stylesheetMain
      [fsUtils.resolve(@path, @metadata.stylesheetMain)]
    else if @metadata.stylesheets
      @metadata.stylesheets.map (name) -> fsUtils.resolve(stylesheetDirPath, name, ['css', 'less', ''])
    else if indexStylesheet = fsUtils.resolve(@path, 'index', ['css', 'less'])
      [indexStylesheet]
    else
      fsUtils.listSync(stylesheetDirPath, ['css', 'less'])

  loadGrammars: ->
    @grammars = []
    grammarsDirPath = path.join(@path, 'grammars')
    for grammarPath in fsUtils.listSync(grammarsDirPath, ['.json', '.cson'])
      @grammars.push(TextMateGrammar.loadSync(grammarPath))

  loadScopedProperties: ->
    @scopedProperties = []
    scopedPropertiessDirPath = path.join(@path, 'scoped-properties')
    for scopedPropertiesPath in fsUtils.listSync(scopedPropertiessDirPath, ['.json', '.cson'])
      for selector, properties of fsUtils.readObjectSync(scopedPropertiesPath)
        @scopedProperties.push([scopedPropertiesPath, selector, properties])

  serialize: ->
    if @mainActivated
      try
        @mainModule?.serialize?()
      catch e
        console.error "Error serializing package '#{@name}'", e.stack

  deactivate: ->
    @unsubscribeFromActivationEvents()
    @deactivateResources()
    @deactivateConfig()
    @mainModule?.deactivate?() if @mainActivated
    @trigger('deactivated')

  deactivateConfig: ->
    @mainModule?.deactivateConfig?()
    @configActivated = false

  deactivateResources: ->
    syntax.removeGrammar(grammar) for grammar in @grammars
    syntax.removeProperties(scopedPropertiesPath) for [scopedPropertiesPath] in @scopedProperties
    keymap.remove(keymapPath) for [keymapPath] in @keymaps
    removeStylesheet(stylesheetPath) for [stylesheetPath] in @stylesheets

  reloadStylesheets: ->
    oldSheets = _.clone(@stylesheets)
    @loadStylesheets()
    removeStylesheet(stylesheetPath) for [stylesheetPath] in oldSheets
    type = if @metadata.theme then 'theme' else 'bundled'
    applyStylesheet(stylesheetPath, content, type) for [stylesheetPath, content] in @stylesheets

  requireMainModule: ->
    return @mainModule if @mainModule?
    mainModulePath = @getMainModulePath()
    @mainModule = require(mainModulePath) if fsUtils.isFileSync(mainModulePath)

  getMainModulePath: ->
    return @mainModulePath if @resolvedMainModulePath
    @resolvedMainModulePath = true
    mainModulePath =
      if @metadata.main
        path.join(@path, @metadata.main)
      else
        path.join(@path, 'index')
    @mainModulePath = fsUtils.resolveExtension(mainModulePath, ["", _.keys(require.extensions)...])

  registerDeferredDeserializers: ->
    for deserializerName in @metadata.deferredDeserializers ? []
      registerDeferredDeserializer deserializerName, => @requireMainModule()

  subscribeToActivationEvents: ->
    return unless @metadata.activationEvents?
    if _.isArray(@metadata.activationEvents)
      rootView.command(event, @handleActivationEvent) for event in @metadata.activationEvents
    else if _.isString(@metadata.activationEvents)
      rootView.command(@metadata.activationEvents, @handleActivationEvent)
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
    else if _.isString(@metadata.activationEvents)
      rootView.off(@metadata.activationEvents, @handleActivationEvent)
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
