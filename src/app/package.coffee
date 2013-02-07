fs = require 'fs'
_ = require 'underscore'

module.exports =
class Package
  @build: (path) ->
    TextMatePackage = require 'text-mate-package'
    AtomPackage = require 'atom-package'

    oldStylePackage = _.find fs.list(path), (filePath) =>
      /index\.coffee$/.test filePath

    if TextMatePackage.testName(path)
      new TextMatePackage(path)
    else
      if not oldStylePackage
        new AtomPackage(path)
      else
        try
          PackageClass = require path
          new PackageClass(path) if typeof PackageClass is 'function'
        catch e
          console.warn "Failed to load package at '#{path}'", e.stack

  name: null
  path: null

  constructor: (@path) ->
    @name = fs.base(@path)

  activate: (rootView) ->
