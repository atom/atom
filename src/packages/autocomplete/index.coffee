AtomPackage = require 'atom-package'
AutocompleteView = require './src/autocomplete-view'

module.exports =
class Autocomplete extends AtomPackage
  activate: (rootView) -> AutocompleteView.activate(rootView)
