DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class GistsPackage extends DeferredAtomPackage

  loadEvents:
    'gist:create': '.editor'

  instanceClass: 'gists/lib/gists'

  onLoadEvent: (event, instance) ->
    instance.createGist(event.currentTargetView())
