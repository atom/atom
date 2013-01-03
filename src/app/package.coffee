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


  name: null
  path: null
  requireModule: null
  module: null

  constructor: (@name) ->
    @path = require.resolve(@name, verifyExistence: false)
    throw new Error("No package found named '#{@name}'") unless @path

    if fs.isDirectory(@path)
      @requireModule = false
    else
      @requireModule = true
      @path = fs.directory(@path)

  load: ->
    for grammar in @getGrammars()
      syntax.addGrammar(grammar)

    for { selector, properties } in @getScopedProperties()
      syntax.addProperties(selector, properties)
