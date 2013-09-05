require 'atom'
{runSpecSuite} = require 'jasmine-helper'

document.title = "Benchmark Suite"
benchmarkSuite = require.resolve('./benchmark-suite')
runSpecSuite(benchmarkSuite, true)
