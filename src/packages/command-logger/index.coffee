DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class CommandLogger extends DeferredAtomPackage

  loadEvents: ['command-logger:toggle']

  instanceClass: 'command-logger/src/command-logger-view'

  onLoadEvent: (event, instance) -> instance.toggle()
