require 'atom'
{runSpecSuite} = require 'jasmine-helper'

atom.openDevTools()

document.title = "Benchmark Suite"
benchmarkSuite = require.resolve('./benchmark-suite')
runSpecSuite(benchmarkSuite, true)
