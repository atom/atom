window.keymap.bindKeys '.editor',
  'ctrl-space': 'autocomplete:attach'

window.keymap.bindKeys '.autocomplete .editor',
  'enter': 'autocomplete:confirm'
  'escape': 'autocomplete:cancel'
  'ctrl-space': 'autocomplete:cancel'
