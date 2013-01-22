AtomPackage = require 'atom-package'
CommandPanelView = require './src/command-panel-view'

module.exports =
class CommandPanel extends AtomPackage
  activate: (rootView, state) -> CommandPanelView.activate(rootView, state)
  deactivate: -> CommandPanelView.deactivate()
  serialize: -> CommandPanelView.serialize()
