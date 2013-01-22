Package = require 'package'
fs = require 'fs'

module.exports =
class AtomPackage extends Package
  metadata: null
  keymapsDirPath: null
  autoloadStylesheets: true

  constructor: (@name) ->
    super
    @keymapsDirPath = fs.join(@path, 'keymaps')

  load: ->
    try
      @loadMetadata()
      @loadKeymaps()
      @loadStylesheets() if @autoloadStylesheets
      rootView.activatePackage(@name, this) unless @isDirectory
    catch e
      console.warn "Failed to load package named '#{@name}'", e.stack
    this

  loadMetadata: ->
    if metadataPath = fs.resolveExtension(fs.join(@path, "package"), ['cson', 'json'])
      @metadata = fs.readObject(metadataPath)

  loadKeymaps: ->
    for keymapPath in @getKeymapPaths()
      keymap.load(keymapPath)

  getKeymapPaths: ->
    if keymaps = @metadata?.keymaps
      keymaps.map (relativePath) =>
        fs.resolve(@keymapsDirPath, relativePath, ['cson', 'json', ''])
    else
      fs.list(@keymapsDirPath)

  loadStylesheets: ->
    for stylesheetPath in @getStylesheetPaths()
      requireStylesheet(stylesheetPath)

  getStylesheetPaths: ->
    stylesheetDirPath = fs.join(@path, 'stylesheets')
    fs.list(stylesheetDirPath)
