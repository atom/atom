DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class JumpToLinePackage extends DeferredAtomPackage

  loadEvents:
    'editor:jump-to-line': '.editor'

  instanceClass: 'jump-to-line/lib/jump-to-line-view'

  onLoadEvent: (event, instance) ->
    instance.toggle(event.currentTargetView())
