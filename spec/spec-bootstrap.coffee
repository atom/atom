# Start the crash reporter before anything else.
require('crash-reporter').start(productName: 'Atom', companyName: 'GitHub')

try
  require '../src/window'
  Atom = require '../src/atom'
  window.atom = Atom.loadOrCreate('spec')
  window.atom.show() unless atom.loadSettings.exitWhenDone
  {runSpecSuite} = require './jasmine-helper'

  document.title = "Spec Suite"
  runSpecSuite './spec-suite'
catch error
  if atom?.loadSettings.exitWhenDone
    console.error(error.stack ? error)
    atom.exit(1)
  else
    throw error
