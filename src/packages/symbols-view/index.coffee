DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class Symbols extends DeferredAtomPackage

  loadEvents: [
    'symbols-view:toggle-file-symbols'
    'symbols-view:toggle-project-symbols'
    'symbols-view:jump-to-declaration'
  ]

  instanceClass: 'symbols-view/src/symbols-view'

  onLoadEvent: (event, instance) ->
    switch event.type
      when 'symbols-view:toggle-file-symbols'
        instance.toggleFileSymbols()
      when 'symbols-view:toggle-project-symbols'
        instance.toggleProjectSymbols()
      when 'symbols-view:jump-to-declaration'
        instance.jumpToDeclaration()
