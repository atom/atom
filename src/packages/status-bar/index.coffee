AtomPackage = require 'atom-package'
StatusBarView = require './src/status-bar-view'

module.exports =
class StatusBar extends AtomPackage
  activate: (rootView) -> StatusBarView.activate(rootView)
