CSON = require 'season'
{basename, join} = require 'path'

### Internal ###
module.exports =
class Package
  @build: (path) ->
    TextMatePackage = require 'text-mate-package'
    AtomPackage = require 'atom-package'

    if TextMatePackage.testName(path)
      new TextMatePackage(path)
    else
      new AtomPackage(path)

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
