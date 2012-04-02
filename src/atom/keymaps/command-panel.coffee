window.keymap.bindKeys '*'
  'meta-:': 'command-panel:toggle'

window.keymap.bindKeys '.command-panel .editor',
  escape: 'command-panel:toggle'
  enter: 'command-panel:execute'

window.keymap.bindKeys '.editor',
  'meta-g': 'command-panel:repeat-relative-address'