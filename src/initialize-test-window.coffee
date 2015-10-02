# Start the crash reporter before anything else.
require('crash-reporter').start(productName: 'Atom', companyName: 'GitHub')

try
  path = require 'path'
  ipc = require 'ipc'

  require '../src/window'
  Atom = require '../src/atom'
  window.atom = new Atom

  # Show window synchronously so a focusout doesn't fire on input elements
  # that are focused in the very first spec run.
  atom.getCurrentWindow().show() unless atom.getLoadSettings().headless

  window.addEventListener 'keydown', (event) ->
    # Reload: cmd-r / ctrl-r
    if (event.metaKey or event.ctrlKey) and event.keyCode is 82
      ipc.send('call-window-method', 'restart')

    # Toggle Dev Tools: cmd-alt-i / ctrl-alt-i
    if (event.metaKey or event.ctrlKey) and event.altKey and event.keyCode is 73
      ipc.send('call-window-method', 'toggleDevTools')

    # Reload: cmd-w / ctrl-w
    if (event.metaKey or event.ctrlKey) and event.keyCode is 87
      ipc.send('call-window-method', 'close')

  # Add 'exports' to module search path.
  exportsPath = path.join(atom.getLoadSettings().resourcePath, 'exports')
  require('module').globalPaths.push(exportsPath)
  process.env.NODE_PATH = exportsPath # Set NODE_PATH env variable since tasks may need it.

  document.title = "Spec Suite"

  testRunner = require(atom.getLoadSettings().testRunnerPath)
  testRunner({
    logFile: atom.getLoadSettings().logFile
    headless: atom.getLoadSettings().headless
    testPaths: atom.getLoadSettings().testPaths
  })

catch error
  if atom?.getLoadSettings().headless
    console.error(error.stack ? error)
    atom.exit(1)
  else
    throw error
