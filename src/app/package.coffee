fs = require 'fs'

module.exports =
class Package
  @load: (name) ->
    AtomPackage = require 'atom-package'
    TextMatePackage = require 'text-mate-package'

    if TextMatePackage.testName(name)
      new TextMatePackage(name).load()
    else
      new AtomPackage(name).load()

  constructor: (@name) ->
    @path = require.resolve(@name, verifyExistence: false)
    throw new Error("No package found named '#{@name}'") unless @path
    @path = fs.directory(@path) unless fs.isDirectory(@path)

  load: ->
    for { selector, properties } in @getScopedProperties()
      syntax.addProperties(selector, properties)
