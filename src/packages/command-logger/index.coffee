AtomPackage = require 'atom-package'
CommandLoggerView = require './src/command-logger-view'

module.exports =
class CommandLogger extends AtomPackage
  activate: (rootView) -> CommandLoggerView.activate(rootView)
