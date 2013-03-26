try
  require 'atom'
  atom.show()
  {runSpecSuite} = require 'jasmine-helper'

  document.title = "Spec Suite"
  runSpecSuite "spec-suite"
catch e
  console.error(e.stack)
  atom.exit(1)
