# Ensure ATOM_HOME is always set before anything else is required
unless process.env.ATOM_HOME
  if process.platform is 'win32'
    home = process.env.USERPROFILE
  else
    home = process.env.HOME
  atomHome = path.join(home, '.atom')
  try
    atomHome = require('fs').realpathSync(atomHome)
  process.env.ATOM_HOME = atomHome

# Like sands through the hourglass, so are the days of our lives.
require './window'

Atom = require './atom'
window.atom = Atom.loadOrCreate('editor')
atom.initialize()
atom.startEditorWindow()

# Workaround for focus getting cleared upon window creation
windowFocused = ->
  window.removeEventListener('focus', windowFocused)
  setTimeout (-> document.querySelector('atom-workspace').focus()), 0
window.addEventListener('focus', windowFocused)
