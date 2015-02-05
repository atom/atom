# Like sands through the hourglass, so are the days of our lives.
console.profile('loading')
require './window'

Atom = require './atom'
window.atom = Atom.loadOrCreate('editor')
atom.initialize()
atom.startEditorWindow()
console.profileEnd('loading')

# Workaround for focus getting cleared upon window creation
windowFocused = ->
  window.removeEventListener('focus', windowFocused)
  setTimeout (-> document.querySelector('atom-workspace').focus()), 0
window.addEventListener('focus', windowFocused)
