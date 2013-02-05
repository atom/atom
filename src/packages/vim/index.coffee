AtomPackage = require 'atom-package'
VimView = require './src/vim'

module.exports =
class Vim extends AtomPackage
  activate: (rootView) -> VimView.activate(rootView)
