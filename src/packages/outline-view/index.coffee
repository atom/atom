DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class Outline extends DeferredAtomPackage

  attachEvents: [
    'outline-view:toggle-file-outline'
    'outline-view:toggle-project-outline'
    'outline-view:jump-to-declaration'
  ]

  instanceClass: 'outline-view/src/outline-view'

  onAttachEvent: (event, instance) ->
    switch event.type
      when 'outline-view:toggle-file-outline'
        instance.toggleFileOutline()
      when 'outline-view:toggle-project-outline'
        instance.toggleProjectOutline()
      when 'outline-view:jump-to-declaration'
        instance.jumpToDeclaration()
