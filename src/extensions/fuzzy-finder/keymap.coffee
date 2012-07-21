window.keymap.bindKeys '*'
  'meta-t': 'fuzzy-finder:toggle-file-finder'
  'meta-b': 'fuzzy-finder:toggle-buffer-finder'

window.keymap.bindKeys ".fuzzy-finder .editor input",
  'enter': 'fuzzy-finder:select-path',
  'escape': 'fuzzy-finder:cancel'
  'meta-w': 'fuzzy-finder:cancel'
