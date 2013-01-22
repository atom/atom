AtomPackage = require 'atom-package'

module.exports =
class MyPackage extends AtomPackage
  activate: ->
    @activateCalled = true
