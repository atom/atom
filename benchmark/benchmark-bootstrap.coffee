require '../src/atom'
{runSpecSuite} = require '../spec/jasmine-helper'

atom.openDevTools()

document.title = "Benchmark Suite"
benchmarkSuite = require.resolve('./benchmark-suite')
runSpecSuite(benchmarkSuite, true)
