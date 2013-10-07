require '../src/window'
Atom = require '../src/atom'
atom = new Atom()
atom.show() unless atom.getLoadSettings().exitWhenDone
window.atom = atom

{runSpecSuite} = require '../spec/jasmine-helper'

atom.openDevTools()

document.title = "Benchmark Suite"
benchmarkSuite = require.resolve('./benchmark-suite')
runSpecSuite(benchmarkSuite, true)
