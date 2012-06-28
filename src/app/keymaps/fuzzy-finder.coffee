window.keymap.bindKeys '*'
  'meta-t': 'fuzzy-finder:toggle'

window.keymap.bindKeys ".fuzzy-finder .editor",
  'enter': 'fuzzy-finder:select-file',
  'escape': 'fuzzy-finder:cancel'
