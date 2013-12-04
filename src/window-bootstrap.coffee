# Like sands through the hourglass, so are the days of our lives.
startTime = Date.now()

# Start the crash reporter before anything else.
require('crash-reporter').start(productName: 'Atom', companyName: 'GitHub')

require './window'

Atom = require './atom'
window.atom = new Atom()
atom.setUpEnvironment('editor')
atom.startEditorWindow()
console.log "Window load time: #{Date.now() - startTime}ms"
