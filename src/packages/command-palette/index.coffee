AtomPackage = require 'atom-package'
CommandPaletteView = require './src/command-palette-view'

module.exports =
class CommandPalette extends AtomPackage
  activate: (rootView) -> CommandPaletteView.activate(rootView)
