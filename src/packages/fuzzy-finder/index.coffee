AtomPackage = require 'atom-package'
FuzzyFinderView = require './src/fuzzy-finder-view'

module.exports =
class FuzzyFinder extends AtomPackage
  activate: (rootView) -> FuzzyFinderView.activate(rootView)
