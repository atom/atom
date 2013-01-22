DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class MarkdownPreview extends DeferredAtomPackage
  attachEvents: ['markdown-preview:toggle']

  instanceClass: 'markdown-preview/src/markdown-preview-view'

  onAttachEvent: (event, instance) -> instance.toggle()
