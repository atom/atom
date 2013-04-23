date = new Date().getTime()
require 'atom'
require 'window'

window.setUpEnvironment()
window.startConfigWindow()
atom.show()
console.log "Load time: #{new Date().getTime() - date}"
