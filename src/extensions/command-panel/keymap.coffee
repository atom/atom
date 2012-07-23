window.keymap.bindKeys '*'
  'ctrl-0': 'command-panel:toggle'
  'ctrl-meta-0': 'command-panel:toggle-preview'
  'meta-:': 'command-panel:toggle'
  'meta-F': 'command-panel:find-in-project'

window.keymap.bindKeys '.command-panel .editor input',
  'meta-w': 'command-panel:toggle'
  escape: 'command-panel:unfocus'
  enter: 'command-panel:execute'

window.keymap.bindKeys '.editor',
  'meta-g': 'command-panel:repeat-relative-address'
  'meta-G': 'command-panel:repeat-relative-address-in-reverse'
  'meta-e': 'command-panel:set-selection-as-regex-address'
  'meta-f': 'command-panel:find-in-file'
