fs = require 'fs'

module.exports =
class Package
  @forName: (name) ->
    AtomPackage = require 'atom-package'
    TextMatePackage = require 'text-mate-package'

    if TextMatePackage.testName(name)
      new TextMatePackage(name)
    else
      new AtomPackage(name)

  constructor: (@name) ->
    @path = require.resolve(@name, verifyExistence: false)
    throw new Error("No package found named '#{@name}'") unless @path
    @path = fs.directory(@path) unless fs.isDirectory(@path)

  load: ->
    # WIP: Going to load scoped properties into `syntax` global here
    @getScopedProperties()
