DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class CommandPanel extends DeferredAtomPackage

  attachEvents: [
    'command-panel:toggle'
    'command-panel:toggle-preview'
    'command-panel:find-in-file'
    'command-panel:find-in-project'
    'command-panel:repeat-relative-address'
    'command-panel:repeat-relative-address-in-reverse'
    'command-panel:set-selection-as-regex-address'
  ]

  instanceClass: 'command-panel/src/command-panel-view'

  onAttachEvent: (event, instance) ->
    switch event.type
      when 'command-panel:toggle'
        instance.toggle()
      when 'command-panel:toggle-preview'
        instance.togglePreview()
      when 'command-panel:find-in-file'
        instance.attach("/")
      when 'command-panel:find-in-project'
        instance.attach("Xx/")
      when 'command-panel:repeat-relative-address'
        instance.repeatRelativeAddress()
      when 'command-panel:repeat-relative-address-in-reverse'
        instance.repeatRelativeAddressInReverse()
      when 'command-panel:set-selection-as-regex-address'
        instance.setSelectionAsLastRelativeAddress()
