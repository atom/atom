# Like sands through the hourglass, so are the days of our lives.
startTime = Date.now()

# Start the crash reporter before anything else.
require('crash-reporter').start(productName: 'Atom', companyName: 'GitHub')

require './window'

Atom = require './atom'
window.atom = Atom.loadOrCreate('editor')
atom.initialize()
atom.startEditorWindow()
window.atom.loadTime = Date.now() - startTime
console.log "Window load time: #{atom.getWindowLoadTime()}ms"
