DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class CommandPalette extends DeferredAtomPackage

  attachEvents: ['command-palette:toggle']

  instanceClass: 'command-palette/src/command-palette-view'

  onAttachEvent: (event, instance) -> instance.attach()
