require 'atom'
{runSpecSuite} = require 'jasmine-helper'

document.title = "Benchmark Suite"
runSpecSuite("benchmark-suite", true)
