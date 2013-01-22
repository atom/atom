AtomPackage = require 'atom-package'
TreeView = require './src/tree-view'

module.exports =
class Tree extends AtomPackage
  activate: (rootView, state) -> TreeView.activate(rootView, state)
  deactivate: -> TreeView.deactivate()
  serialize: -> TreeView.serialize()
