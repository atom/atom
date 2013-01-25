DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class GoToLinePackage extends DeferredAtomPackage

  loadEvents:
    'editor:go-to-line': '.editor'

  instanceClass: 'go-to-line/lib/go-to-line-view'

  onLoadEvent: (event, instance) ->
    instance.toggle(event.currentTargetView())
