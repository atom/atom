# Start the crash reporter before anything else.
require('crash-reporter').start(productName: 'Atom', companyName: 'GitHub')

try
  require '../src/window'
  Atom = require '../src/atom'
  window.atom = Atom.loadOrCreate('spec')

  # Show window synchronously so a focusout doesn't fire on input elements
  # that are focused in the very first spec run.
  atom.getCurrentWindow().show() unless atom.getLoadSettings().exitWhenDone

  {runSpecSuite} = require './jasmine-helper'

  document.title = "Spec Suite"
  runSpecSuite './spec-suite', atom.getLoadSettings().logFile
catch error
  if atom?.getLoadSettings().exitWhenDone
    console.error(error.stack ? error)
    atom.exit(1)
  else
    throw error
