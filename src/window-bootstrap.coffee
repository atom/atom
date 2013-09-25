# Like sands through the hourglass, so are the days of our lives.
startTime = new Date().getTime()

require './atom'
require './window'

window.setUpEnvironment('editor')
window.startEditorWindow()
console.log "Window load time: #{new Date().getTime() - startTime}ms"
