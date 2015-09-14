Q = require 'q'
Package = require './package'

module.exports =
class PackageSet extends Package
  load: ->
    @loadTime = 0
    this

  activate: ->
    Promise.resolve()
