DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class EditorStats extends DeferredAtomPackage
  loadEvents: ['editor-stats:toggle']

  instanceClass: 'editor-stats/src/editor-stats-view'

  onLoadEvent: (event, instance) -> instance.toggle()
