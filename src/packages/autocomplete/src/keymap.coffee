window.keymap.bindKeys '.editor',
  'ctrl-space': 'autocomplete:attach'

window.keymap.bindKeys '.autocomplete .editor',
  'ctrl-space': 'core:cancel'

window.keymap.bindKeys ".autocomplete .mini.editor input",
  'enter': 'core:confirm'
