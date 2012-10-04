window.keymap.bindKeys 'body'
  'meta-t': 'fuzzy-finder:toggle-file-finder'
  'meta-b': 'fuzzy-finder:toggle-buffer-finder'

window.keymap.bindKeys ".fuzzy-finder .editor input",
  'enter': 'core:confirm',
  'escape': 'core:cancel'
  'meta-w': 'core:cancel'
