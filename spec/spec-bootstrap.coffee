try
  require '../src/window'
  Atom = require '../src/atom'
  window.atom = new Atom()
  window.atom.show() unless atom.getLoadSettings().exitWhenDone
  {runSpecSuite} = require './jasmine-helper'

  document.title = "Spec Suite"
  runSpecSuite './spec-suite'
catch error
  unless atom.getLoadSettings().exitWhenDone
    atom.getCurrentWindow().setSize(800, 600)
    atom.getCurrentWindow().center()
    atom.openDevTools()

  console.error(error.stack ? error)
  atom.exit(1) if atom.getLoadSettings().exitWhenDone
