AtomPackage = require 'atom-package'
TabsView = require './src/tabs-view'

module.exports =
class Tabs extends AtomPackage
  activate: (rootView) -> TabsView.activate(rootView)
