# Like sands through the hourglass, so are the days of our lives.
startTime = Date.now()

require './window'

Atom = require './atom'
window.atom = Atom.loadOrCreate('editor')
atom.initialize()
atom.startEditorWindow()
window.atom.loadTime = Date.now() - startTime
console.log "Window load time: #{atom.getWindowLoadTime()}ms"
