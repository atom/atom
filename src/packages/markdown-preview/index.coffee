AtomPackage = require 'atom-package'
MarkdownPreviewView = require './src/markdown-preview-view'

module.exports =
class MarkdownPreview extends AtomPackage
  activate: (rootView) -> MarkdownPreviewView.activate(rootView)
