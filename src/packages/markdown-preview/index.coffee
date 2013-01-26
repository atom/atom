DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class MarkdownPreview extends DeferredAtomPackage
  loadEvents: ['markdown-preview:toggle']

  instanceClass: 'markdown-preview/src/markdown-preview-view'

  onLoadEvent: (event, instance) -> instance.toggle()
