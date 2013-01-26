DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class CommandPalette extends DeferredAtomPackage

  loadEvents: ['command-palette:toggle']

  instanceClass: 'command-palette/src/command-palette-view'

  onLoadEvent: (event, instance) -> instance.attach()
