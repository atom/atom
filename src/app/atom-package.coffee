Package = require 'package'
fs = require 'fs'

module.exports =
class AtomPackage extends Package
  metadata: null
  keymapsDirPath: null

  constructor: (@name) ->
    super
    @keymapsDirPath = fs.join(@path, 'keymaps')
    if @requireModule
      @module = require(@path)
      @module.name = @name

  load: ->
    @loadMetadata()
    @loadKeymaps()
    @loadStylesheets()
    rootView.activatePackage(@name, @module) if @module

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
      if fs.exists(@keymapsDirPath)
        fs.list(@keymapsDirPath)
      else
        []

  loadStylesheets: ->
    for stylesheetPath in @getStylesheetPaths()
      requireStylesheet(stylesheetPath)

  getStylesheetPaths: ->
    stylesheetDirPath = fs.join(@path, 'stylesheets')
    if fs.exists stylesheetDirPath
      fs.list stylesheetDirPath
    else
      []
