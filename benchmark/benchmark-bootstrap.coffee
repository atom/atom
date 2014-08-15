require '../src/window'
Atom = require '../src/atom'
window.atom = Atom.loadOrCreate('spec')
atom.show() unless atom.getLoadSettings().exitWhenDone
window.atom = atom

{runSpecSuite} = require '../spec/jasmine-helper'

atom.openDevTools()

document.title = "Benchmark Suite"
runSpecSuite('../benchmark/benchmark-suite', atom.getLoadSettings().logFile)
