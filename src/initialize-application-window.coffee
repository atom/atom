# Like sands through the hourglass, so are the days of our lives.
module.exports = ({blobStore}) ->
  environmentHelpers = require('./environment-helpers')
  path = require 'path'
  require './window'
  {getWindowLoadSettings} = require './window-load-settings-helpers'
  {ipcRenderer} = require 'electron'
  {resourcePath, isSpec, devMode, env} = getWindowLoadSettings()

  # Set baseline environment
  environmentHelpers.normalize({env: env})
  env = process.env

  # Add application-specific exports to module search path.
  exportsPath = path.join(resourcePath, 'exports')
  require('module').globalPaths.push(exportsPath)
  process.env.NODE_PATH = exportsPath

  # Make React faster
  process.env.NODE_ENV ?= 'production' unless devMode

  AtomEnvironment = require './atom-environment'
  ApplicationDelegate = require './application-delegate'
  window.atom = new AtomEnvironment({
    window, document, blobStore,
    applicationDelegate: new ApplicationDelegate,
    configDirPath: process.env.ATOM_HOME
    enablePersistence: true
    env: process.env
  })

  atom.startEditorWindow().then ->

    # Workaround for focus getting cleared upon window creation
    windowFocused = ->
      window.removeEventListener('focus', windowFocused)
      setTimeout (-> document.querySelector('atom-workspace').focus()), 0
    window.addEventListener('focus', windowFocused)
    ipcRenderer.on('environment', (event, env) ->
      environmentHelpers.replace(env)
    )
