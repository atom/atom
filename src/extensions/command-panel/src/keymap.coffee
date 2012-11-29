window.keymap.bindKeys '*'
  'meta-:': 'command-panel:toggle-preview'
  'meta-;': 'command-panel:toggle'
  'meta-F': 'command-panel:find-in-project'

window.keymap.bindKeys '.command-panel .preview-list, .command-panel .editor input',
  'enter': 'core:confirm'

window.keymap.bindKeys '.editor',
  'meta-g': 'command-panel:repeat-relative-address'
  'meta-G': 'command-panel:repeat-relative-address-in-reverse'
  'meta-e': 'command-panel:set-selection-as-regex-address'
  'meta-f': 'command-panel:find-in-file'
  'meta-F': 'command-panel:find-in-project'
