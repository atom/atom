# Like sands through the hourglass, so are the days of our lives.
startTime = new Date().getTime()

require './window'

Atom = require './atom'
window.atom = new Atom()
window.setUpEnvironment('editor')
window.startEditorWindow()
console.log "Window load time: #{new Date().getTime() - startTime}ms"
