cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports = ({blobStore}) ->
  # Start the crash reporter before anything else.
  require('crash-reporter').start(productName: 'Atom', companyName: 'GitHub')
  remote = require 'remote'

  exitWithStatusCode = (status) ->
    remote.require('app').emit('will-quit')
    remote.process.exit(status)

  try
    path = require 'path'
    ipc = require 'ipc'
    {getWindowLoadSettings} = require './window-load-settings-helpers'
    AtomEnvironment = require '../src/atom-environment'
    ApplicationDelegate = require '../src/application-delegate'

    {testRunnerPath, legacyTestRunnerPath, headless, logFile, testPaths} = getWindowLoadSettings()

    unless headless
      # Show window synchronously so a focusout doesn't fire on input elements
      # that are focused in the very first spec run.
      remote.getCurrentWindow().show()

    handleKeydown = (event) ->
      # Reload: cmd-r / ctrl-r
      if (event.metaKey or event.ctrlKey) and event.keyCode is 82
        ipc.send('call-window-method', 'restart')

      # Toggle Dev Tools: cmd-alt-i / ctrl-alt-i
      if (event.metaKey or event.ctrlKey) and event.altKey and event.keyCode is 73
        ipc.send('call-window-method', 'toggleDevTools')

      # Reload: cmd-w / ctrl-w
      if (event.metaKey or event.ctrlKey) and event.keyCode is 87
        ipc.send('call-window-method', 'close')

    window.addEventListener('keydown', handleKeydown, true)

    # Add 'exports' to module search path.
    exportsPath = path.join(getWindowLoadSettings().resourcePath, 'exports')
    require('module').globalPaths.push(exportsPath)
    process.env.NODE_PATH = exportsPath # Set NODE_PATH env variable since tasks may need it.

    document.title = "Spec Suite"

    # Avoid throttling of test window by playing silence
    # See related discussion in https://github.com/atom/atom/pull/9485
    context = new AudioContext()
    source = context.createBufferSource()
    source.connect(context.destination)
    source.start(0)

    testRunner = require(testRunnerPath)
    legacyTestRunner = require(legacyTestRunnerPath)
    buildDefaultApplicationDelegate = -> new ApplicationDelegate()
    buildAtomEnvironment = (params) ->
      params = cloneObject(params)
      params.blobStore = blobStore unless params.hasOwnProperty("blobStore")
      params.onlyLoadBaseStyleSheets = true unless params.hasOwnProperty("onlyLoadBaseStyleSheets")
      new AtomEnvironment(params)

    promise = testRunner({
      logFile, headless, testPaths, buildAtomEnvironment, buildDefaultApplicationDelegate, legacyTestRunner
    })

    promise.then(exitWithStatusCode) if getWindowLoadSettings().headless
  catch error
    if getWindowLoadSettings().headless
      console.error(error.stack ? error)
      exitWithStatusCode(1)
    else
      throw error
