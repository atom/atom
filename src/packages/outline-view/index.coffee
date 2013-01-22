AtomPackage = require 'atom-package'
OutlineView = require './src/outline-view'

module.exports =
class Outline extends AtomPackage
  activate: (rootView) -> OutlineView.activate(rootView)
