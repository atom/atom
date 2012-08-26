window.keymap.bindKeys '.editor',
  'escape': 'autocomplete:attach'
  'ctrl-space': 'autocomplete:attach'

window.keymap.bindKeys '.autocomplete .editor',
  'enter': 'autocomplete:confirm'
  'escape': 'autocomplete:cancel'
  'ctrl-space': 'autocomplete:cancel'
