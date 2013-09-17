try
  require 'atom'
  atom.show()
  {runSpecSuite} = require './jasmine-helper'

  document.title = "Spec Suite"
  runSpecSuite './spec-suite'
catch e
  console.error(e.stack ? e)
  atom.exit(1) if atom.getLoadSettings().exitWhenDone
