# Like sands through the hourglass, so are the days of our lives.
date = new Date().getTime()
require 'atom'
require 'window'

window.setUpEnvironment()
window.startup()
atom.show()
console.log "Load time: #{new Date().getTime() - date}"
