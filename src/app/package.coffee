fs = require 'fs'

module.exports =
class Package
  @resolve: (name) ->
    path = require.resolve(name, verifyExistence: false)
    return path if path
    throw new Error("No package found named '#{name}'")

  @build: (name) ->
    TextMatePackage = require 'text-mate-package'
    AtomPackage = require 'atom-package'
    if TextMatePackage.testName(name)
      new TextMatePackage(name)
    else
      if fs.isDirectory(@resolve(name))
        new AtomPackage(name)
      else
        try
          PackageClass = require name
          new PackageClass(name) if typeof PackageClass is 'function'
        catch e
          console.warn "Failed to load package named '#{name}'", e.stack

  name: null
  path: null
  isDirectory: false
  module: null

  constructor: (@name) ->
    @path = Package.resolve(@name)
    @isDirectory = fs.isDirectory(@path)
    @path = fs.directory(@path) unless @isDirectory

  activate: (rootView) ->
