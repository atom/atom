AtomPackage = require 'atom-package'
WrapGuideView = require './src/wrap-guide-view'

module.exports =
class WrapGuide extends AtomPackage
  activate: (rootView) -> WrapGuideView.activate(rootView)
