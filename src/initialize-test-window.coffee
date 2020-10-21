ipcHelpers = require './ipc-helpers'

cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports = ({blobStore}) ->
  {remote} = require 'electron'

  exitWithStatusCode = (status) ->
    remote.app.emit('will-quit')
    remote.process.exit(status)

  try
    path = require 'path'
    {ipcRenderer} = require 'electron'
    getWindowLoadSettings = require './get-window-load-settings'
    CompileCache = require './compile-cache'
    AtomEnvironment = require '../src/atom-environment'
    ApplicationDelegate = require '../src/application-delegate'
    Clipboard = require '../src/clipboard'
    TextEditor = require '../src/text-editor'
    {updateProcessEnv} = require('./update-process-env')
    require './electron-shims'

    ipcRenderer.on 'environment', (event, env) ->
      updateProcessEnv(env)

    {testRunnerPath, legacyTestRunnerPath, headless, logFile, testPaths, env} = getWindowLoadSettings()

    if headless
      # Install console functions that output to stdout and stderr.
      util = require 'util'

      Object.defineProperties process,
        stdout: {value: remote.process.stdout}
        stderr: {value: remote.process.stderr}

      console.log = (args...) -> process.stdout.write "#{util.format(args...)}\n"
      console.error = (args...) -> process.stderr.write "#{util.format(args...)}\n"
    else
      # Show window synchronously so a focusout doesn't fire on input elements
      # that are focused in the very first spec run.
      remote.getCurrentWindow().show()

    handleKeydown = (event) ->
      # Reload: cmd-r / ctrl-r
      if (event.metaKey or event.ctrlKey) and event.keyCode is 82
        ipcHelpers.call('window-method', 'reload')

      # Toggle Dev Tools: cmd-alt-i (Mac) / ctrl-shift-i (Linux/Windows)
      if event.keyCode is 73 and (
        (process.platform is 'darwin' and event.metaKey and event.altKey) or
        (process.platform isnt 'darwin' and event.ctrlKey and event.shiftKey))
          ipcHelpers.call('window-method', 'toggleDevTools')

      # Close: cmd-w / ctrl-w
      if (event.metaKey or event.ctrlKey) and event.keyCode is 87
        ipcHelpers.call('window-method', 'close')

      # Copy: cmd-c / ctrl-c
      if (event.metaKey or event.ctrlKey) and event.keyCode is 67
        atom.clipboard.write(window.getSelection().toString())

    window.addEventListener('keydown', handleKeydown, {capture: true})

    # Add 'exports' to module search path.
    exportsPath = path.join(getWindowLoadSettings().resourcePath, 'exports')
    require('module').globalPaths.push(exportsPath)
    process.env.NODE_PATH = exportsPath # Set NODE_PATH env variable since tasks may need it.

    updateProcessEnv(env)

    # Set up optional transpilation for packages under test if any
    FindParentDir = require 'find-parent-dir'
    if packageRoot = FindParentDir.sync(testPaths[0], 'package.json')
      packageMetadata = require(path.join(packageRoot, 'package.json'))
      if packageMetadata.atomTranspilers
        CompileCache.addTranspilerConfigForPath(packageRoot, packageMetadata.name, packageMetadata, packageMetadata.atomTranspilers)

    document.title = "Spec Suite"

    clipboard = new Clipboard
    TextEditor.setClipboard(clipboard)
    TextEditor.viewForItem = (item) -> atom.views.getView(item)

    testRunner = require(testRunnerPath)
    legacyTestRunner = require(legacyTestRunnerPath)
    buildDefaultApplicationDelegate = -> new ApplicationDelegate()
    buildAtomEnvironment = (params) ->
      params = cloneObject(params)
      params.clipboard = clipboard unless params.hasOwnProperty("clipboard")
      params.blobStore = blobStore unless params.hasOwnProperty("blobStore")
      params.onlyLoadBaseStyleSheets = true unless params.hasOwnProperty("onlyLoadBaseStyleSheets")
      atomEnvironment = new AtomEnvironment(params)
      atomEnvironment.initialize(params)
      TextEditor.setScheduler(atomEnvironment.views)
      atomEnvironment

    promise = testRunner({
      logFile, headless, testPaths, buildAtomEnvironment, buildDefaultApplicationDelegate, legacyTestRunner
    })

    promise.then (statusCode) ->
      exitWithStatusCode(statusCode) if getWindowLoadSettings().headless
  catch error
    if getWindowLoadSettings().headless
      console.error(error.stack ? error)
      exitWithStatusCode(1)
    else
      throw error
