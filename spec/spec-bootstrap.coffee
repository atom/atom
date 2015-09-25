# Start the crash reporter before anything else.
require('crash-reporter').start(productName: 'Atom', companyName: 'GitHub')

path = require 'path'

try
  require '../src/window'
  Atom = require '../src/atom'
  window.atom = Atom.loadOrCreate('spec')

  # Show window synchronously so a focusout doesn't fire on input elements
  # that are focused in the very first spec run.
  atom.getCurrentWindow().show() unless atom.getLoadSettings().headless

  # Add 'exports' to module search path.
  exportsPath = path.join(atom.getLoadSettings().resourcePath, 'exports')
  require('module').globalPaths.push(exportsPath)
  process.env.NODE_PATH = exportsPath # Set NODE_PATH env variable since tasks may need it.

  document.title = "Spec Suite"

  testRunner = require('./jasmine-test-runner')
  testRunner({
    logFile: atom.getLoadSettings().logFile
    headless: atom.getLoadSettings().headless
    testPaths: [atom.getLoadSettings().specDirectory]
  })

catch error
  if atom?.getLoadSettings().headless
    console.error(error.stack ? error)
    atom.exit(1)
  else
    throw error
