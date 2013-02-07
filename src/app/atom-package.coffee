Package = require 'package'
fs = require 'fs'
_ = require 'underscore'

module.exports =
class AtomPackage extends Package
  metadata: null
  keymapsDirPath: null
  autoloadStylesheets: true

  constructor: ->
    super
    @keymapsDirPath = fs.join(@path, 'keymaps')

  load: ->
    try
      @loadMetadata()
      @loadKeymaps()
      @loadStylesheets() if @autoloadStylesheets
      if activationEvents = @getActivationEvents()
        @subscribeToActivationEvents(activationEvents)
      else
        @activatePackageMain()
    catch e
      console.warn "Failed to load package named '#{@name}'", e.stack
    this

  subscribeToActivationEvents: (activationEvents) ->
    if _.isArray(activationEvents)
      activateHandler = =>
        @activatePackageMain()
        for event in activationEvents
          rootView.off event, activateHandler
      for event in activationEvents
        rootView.command event, activateHandler
    else
      activateHandler = =>
        @activatePackageMain()
        for event, selector of activationEvents
          rootView.off event, selector, activateHandler
      for event, selector of activationEvents
        rootView.command event, selector, activateHandler

  activatePackageMain: ->
    if packageMain = @getPackageMain()
      rootView?.activatePackage(@name, packageMain)

  getPackageMain: ->
    mainPath = require.resolve(@metadata.main) if @metadata.main
    if mainPath
      require(mainPath)
    else if require.resolve(@path)
      this

  getActivationEvents: -> @metadata.activationEvents

  loadMetadata: ->
    if metadataPath = fs.resolveExtension(fs.join(@path, "package"), ['cson', 'json'])
      @metadata = fs.readObject(metadataPath)
    @metadata ?= {}

  loadKeymaps: ->
    if keymaps = @metadata.keymaps
      keymaps = keymaps.map (relativePath) =>
        fs.resolve(@keymapsDirPath, relativePath, ['cson', 'json', ''])
      keymap.load(keymapPath) for keymapPath in keymaps
    else
      keymap.loadDirectory(@keymapsDirPath)

  loadStylesheets: ->
    for stylesheetPath in @getStylesheetPaths()
      requireStylesheet(stylesheetPath)

  getStylesheetPaths: ->
    stylesheetDirPath = fs.join(@path, 'stylesheets')
    fs.list(stylesheetDirPath)
