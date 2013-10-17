try
  require '../src/window'
  Atom = require '../src/atom'
  window.atom = new Atom()
  window.atom.show() unless atom.getLoadSettings().exitWhenDone
  {runSpecSuite} = require './jasmine-helper'

  document.title = "Spec Suite"
  runSpecSuite './spec-suite'
catch error
  if atom?.getLoadSettings().exitWhenDone
    console.error(error.stack ? error)
    atom.exit(1)
  else
    throw error
