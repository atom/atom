# Like sands through the hourglass, so are the days of our lives.
require 'window'
Atom = require 'atom'
window.atom = new Atom(atom.loadPath, $native)
window.startup $pathToOpen

