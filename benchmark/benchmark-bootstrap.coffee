require '../src/window'
Atom = require '../src/atom'
window.atom = new Atom()

{runSpecSuite} = require '../spec/jasmine-helper'

atom.openDevTools()

document.title = "Benchmark Suite"
benchmarkSuite = require.resolve('./benchmark-suite')
runSpecSuite(benchmarkSuite, true)
