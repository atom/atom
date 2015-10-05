# Like sands through the hourglass, so are the days of our lives.

path = require 'path'
require './window'
{getWindowLoadSettings} = require './window-load-settings-helpers'

{resourcePath, isSpec, devMode} = getWindowLoadSettings()

# Add application-specific exports to module search path.
exportsPath = path.join(resourcePath, 'exports')
require('module').globalPaths.push(exportsPath)
process.env.NODE_PATH = exportsPath

# Make React faster
process.env.NODE_ENV ?= 'production' unless devMode

AtomEnvironment = require './atom-environment'
window.atom = new AtomEnvironment

atom.displayWindow()
atom.loadStateSync()
atom.startEditorWindow()

# Workaround for focus getting cleared upon window creation
windowFocused = ->
  window.removeEventListener('focus', windowFocused)
  setTimeout (-> document.querySelector('atom-workspace').focus()), 0
window.addEventListener('focus', windowFocused)
