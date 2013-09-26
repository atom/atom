# Like sands through the hourglass, so are the days of our lives.
startTime = new Date().getTime()

Atom = require './atom'
require './window'

window.atom = new Atom()
window.setUpEnvironment('editor')
window.startEditorWindow()
console.log "Window load time: #{new Date().getTime() - startTime}ms"
