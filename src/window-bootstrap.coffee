# Like sands through the hourglass, so are the days of our lives.
require 'atom'
require 'window'

pathToOpen = atom.getWindowState('pathToOpen') ? window.location.params.pathToOpen
window.attachRootView(pathToOpen)
atom.show()
