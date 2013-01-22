DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class CommandLogger extends DeferredAtomPackage
  attachEvents: ['command-logger:toggle']

  instanceClass: 'command-logger/src/command-logger-view'

  onAttachEvent: (event, instance) -> instance.toggle()
