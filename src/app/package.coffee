fs = require 'fs'

module.exports =
class Package
  @build: (name) ->
    AtomPackage = require 'atom-package'
    TextMatePackage = require 'text-mate-package'
    if TextMatePackage.testName(name)
      new TextMatePackage(name)
    else
      new AtomPackage(name)

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
