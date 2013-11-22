# Like sands through the hourglass, so are the days of our lives.
startTime = Date.now()

require './window'

Atom = require './atom'
window.atom = new Atom()
atom.setUpEnvironment('editor')
atom.startEditorWindow()
console.log "Window load time: #{Date.now() - startTime}ms"
