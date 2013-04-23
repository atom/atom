fsUtils = require 'fs-utils'

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

  name: null
  path: null

  constructor: (@path) ->
    @name = fsUtils.base(@path)
