# Like sands through the hourglass, so are the days of our lives.
date = new Date().getTime()
require 'atom'
require 'window'

pathToOpen = atom.getWindowState('pathToOpen') ? window.location.params.pathToOpen
window.attachRootView(pathToOpen)
atom.show()
console.log "Load time: #{new Date().getTime() - date}"
