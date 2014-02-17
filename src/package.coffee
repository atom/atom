path = require 'path'
CSON = require 'season'

module.exports =
class Package
  @build: (packagePath) ->
    AtomPackage = require './atom-package'
    ThemePackage = require './theme-package'

    try
      metadata = @loadMetadata(packagePath)
      if metadata.theme
        pack = new ThemePackage(packagePath, {metadata})
      else
        pack = new AtomPackage(packagePath, {metadata})
    catch e
      console.warn "Failed to load package.json '#{path.basename(packagePath)}'", e.stack ? e

    pack

  @load: (packagePath) ->
    pack = @build(packagePath)
    pack?.load()
    pack

  @loadMetadata: (packagePath, ignoreErrors=false) ->
    if metadataPath = CSON.resolve(path.join(packagePath, 'package'))
      try
        metadata = CSON.readFileSync(metadataPath)
      catch e
        throw e unless ignoreErrors
    metadata ?= {}
    metadata.name = basename(packagePath)
    metadata

  constructor: (@path) ->
    @name = path.basename(@path)

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
