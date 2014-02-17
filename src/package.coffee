CSON = require 'season'
{basename, join} = require 'path'

module.exports =
class Package
  @build: (path) ->
    AtomPackage = require './atom-package'
    ThemePackage = require './theme-package'

    try
      metadata = @loadMetadata(path)
      if metadata.theme
        pack = new ThemePackage(path, {metadata})
      else
        pack = new AtomPackage(path, {metadata})
    catch e
      console.warn "Failed to load package.json '#{basename(path)}'", e.stack ? e

    pack

  @load: (path) ->
    pack = @build(path)
    pack?.load()
    pack

  @loadMetadata: (path, ignoreErrors=false) ->
    if metadataPath = CSON.resolve(join(path, 'package'))
      try
        metadata = CSON.readFileSync(metadataPath)
      catch e
        throw e unless ignoreErrors
    metadata ?= {}
    metadata.name = basename(path)
    metadata

  name: null
  path: null

  constructor: (@path) ->
    @name = basename(@path)

  enable: ->
    atom.config.removeAtKeyPath('core.disabledPackages', @metadata.name)

  disable: ->
    atom.config.pushAtKeyPath('core.disabledPackages', @metadata.name)

  isTheme: ->
    @metadata?.theme?

  measure: (key, fn) ->
    startTime = Date.now()
    value = fn()
    @[key] = Date.now() - startTime
    value
