CSON = require 'season'
{basename, join} = require 'path'

### Internal ###
module.exports =
class Package
  @build: (path) ->
    TextMatePackage = require './text-mate-package'
    AtomPackage = require './atom-package'
    ThemePackage = require './theme-package'

    if TextMatePackage.testName(path)
      new TextMatePackage(path)
    else
      metadata = @loadMetadata(path)
      if metadata.theme
        new ThemePackage(path, {metadata})
      else
        new AtomPackage(path, {metadata})

  @load: (path, options) ->
    pack = @build(path)
    pack.load(options)
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

  isActive: ->
    atom.isPackageActive(@name)

  isTheme: ->
    !!@metadata?.theme

  # Private:
  measure: (key, fn) ->
    startTime = new Date().getTime()
    fn()
    @[key] = new Date().getTime() - startTime
