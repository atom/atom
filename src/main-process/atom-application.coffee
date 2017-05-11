AtomWindow = require './atom-window'
ApplicationMenu = require './application-menu'
AtomProtocolHandler = require './atom-protocol-handler'
AutoUpdateManager = require './auto-update-manager'
StorageFolder = require '../storage-folder'
Config = require '../config'
FileRecoveryService = require './file-recovery-service'
ipcHelpers = require '../ipc-helpers'
{BrowserWindow, Menu, app, dialog, ipcMain, shell, screen} = require 'electron'
{CompositeDisposable, Disposable} = require 'event-kit'
fs = require 'fs-plus'
path = require 'path'
os = require 'os'
net = require 'net'
url = require 'url'
{EventEmitter} = require 'events'
_ = require 'underscore-plus'
FindParentDir = null
Resolve = null
ConfigSchema = require '../config-schema'

LocationSuffixRegExp = /(:\d+)(:\d+)?$/

# The application's singleton class.
#
# It's the entry point into the Atom application and maintains the global state
# of the application.
#
module.exports =
class AtomApplication
  Object.assign @prototype, EventEmitter.prototype

  # Public: The entry point into the Atom application.
  @open: (options) ->
    unless options.socketPath?
      if process.platform is 'win32'
        userNameSafe = new Buffer(process.env.USERNAME).toString('base64')
        options.socketPath = "\\\\.\\pipe\\atom-#{options.version}-#{userNameSafe}-#{process.arch}-sock"
      else
        options.socketPath = path.join(os.tmpdir(), "atom-#{options.version}-#{process.env.USER}.sock")

    # FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    # take a few seconds to trigger 'error' event, it could be a bug of node
    # or atom-shell, before it's fixed we check the existence of socketPath to
    # speedup startup.
    if (process.platform isnt 'win32' and not fs.existsSync options.socketPath) or options.test or options.benchmark or options.benchmarkTest
      new AtomApplication(options).initialize(options)
      return

    client = net.connect {path: options.socketPath}, ->
      client.write JSON.stringify(options), ->
        client.end()
        app.quit()

    client.on 'error', -> new AtomApplication(options).initialize(options)

  windows: null
  applicationMenu: null
  atomProtocolHandler: null
  resourcePath: null
  version: null
  quitting: false

  exit: (status) -> app.exit(status)

  constructor: (options) ->
    {@resourcePath, @devResourcePath, @version, @devMode, @safeMode, @socketPath, @logFile, @userDataDir} = options
    @socketPath = null if options.test or options.benchmark or options.benchmarkTest
    @pidsToOpenWindows = {}
    @windows = []

    @config = new Config({enablePersistence: true})
    @config.setSchema null, {type: 'object', properties: _.clone(ConfigSchema)}
    ConfigSchema.projectHome = {
      type: 'string',
      default: path.join(fs.getHomeDirectory(), 'github'),
      description: 'The directory where projects are assumed to be located. Packages created using the Package Generator will be stored here by default.'
    }
    @config.initialize({configDirPath: process.env.ATOM_HOME, @resourcePath, projectHomeSchema: ConfigSchema.projectHome})
    @config.load()
    @fileRecoveryService = new FileRecoveryService(path.join(process.env.ATOM_HOME, "recovery"))
    @storageFolder = new StorageFolder(process.env.ATOM_HOME)
    @autoUpdateManager = new AutoUpdateManager(
      @version,
      options.test or options.benchmark or options.benchmarkTest,
      @config
    )

    @disposable = new CompositeDisposable
    @handleEvents()

  # This stuff was previously done in the constructor, but we want to be able to construct this object
  # for testing purposes without booting up the world. As you add tests, feel free to move instantiation
  # of these various sub-objects into the constructor, but you'll need to remove the side-effects they
  # perform during their construction, adding an initialize method that you call here.
  initialize: (options) ->
    global.atomApplication = this

    # DEPRECATED: This can be removed at some point (added in 1.13)
    # It converts `useCustomTitleBar: true` to `titleBar: "custom"`
    if process.platform is 'darwin' and @config.get('core.useCustomTitleBar')
      @config.unset('core.useCustomTitleBar')
      @config.set('core.titleBar', 'custom')

    @config.onDidChange 'core.titleBar', @promptForRestart.bind(this)

    process.nextTick => @autoUpdateManager.initialize()
    @applicationMenu = new ApplicationMenu(@version, @autoUpdateManager)
    @atomProtocolHandler = new AtomProtocolHandler(@resourcePath, @safeMode)

    @listenForArgumentsFromNewProcess()
    @setupDockMenu()

    @launch(options)

  destroy: ->
    windowsClosePromises = @windows.map (window) ->
      window.close()
      window.closedPromise
    Promise.all(windowsClosePromises).then(=> @disposable.dispose())

  launch: (options) ->
    if options.pathsToOpen?.length > 0 or options.urlsToOpen?.length > 0 or options.test or options.benchmark or options.benchmarkTest
      if @config.get('core.restorePreviousWindowsOnStart') is 'always'
        @loadState(_.deepClone(options))
      @openWithOptions(options)
    else
      @loadState(options) or @openPath(options)

  openWithOptions: (options) ->
    {
      initialPaths, pathsToOpen, executedFrom, urlsToOpen, benchmark,
      benchmarkTest, test, pidToKillWhenClosed, devMode, safeMode, newWindow,
      logFile, profileStartup, timeout, clearWindowState, addToLastWindow, env
    } = options

    app.focus()

    if test
      @runTests({
        headless: true, devMode, @resourcePath, executedFrom, pathsToOpen,
        logFile, timeout, env
      })
    else if benchmark or benchmarkTest
      @runBenchmarks({headless: true, test: benchmarkTest, @resourcePath, executedFrom, pathsToOpen, timeout, env})
    else if pathsToOpen.length > 0
      @openPaths({
        initialPaths, pathsToOpen, executedFrom, pidToKillWhenClosed, newWindow,
        devMode, safeMode, profileStartup, clearWindowState, addToLastWindow, env
      })
    else if urlsToOpen.length > 0
      for urlToOpen in urlsToOpen
        @openUrl({urlToOpen, devMode, safeMode, env})
    else
      # Always open a editor window if this is the first instance of Atom.
      @openPath({
        initialPaths, pidToKillWhenClosed, newWindow, devMode, safeMode, profileStartup,
        clearWindowState, addToLastWindow, env
      })

  # Public: Removes the {AtomWindow} from the global window list.
  removeWindow: (window) ->
    @windows.splice(@windows.indexOf(window), 1)
    if @windows.length is 0
      @applicationMenu?.enableWindowSpecificItems(false)
      if process.platform in ['win32', 'linux']
        app.quit()
        return
    @saveState(true) unless window.isSpec

  # Public: Adds the {AtomWindow} to the global window list.
  addWindow: (window) ->
    @windows.push window
    @applicationMenu?.addWindow(window.browserWindow)
    window.once 'window:loaded', =>
      @autoUpdateManager?.emitUpdateAvailableEvent(window)

    unless window.isSpec
      focusHandler = => @lastFocusedWindow = window
      blurHandler = => @saveState(false)
      window.browserWindow.on 'focus', focusHandler
      window.browserWindow.on 'blur', blurHandler
      window.browserWindow.once 'closed', =>
        @lastFocusedWindow = null if window is @lastFocusedWindow
        window.browserWindow.removeListener 'focus', focusHandler
        window.browserWindow.removeListener 'blur', blurHandler
      window.browserWindow.webContents.once 'did-finish-load', => @saveState(false)

  # Creates server to listen for additional atom application launches.
  #
  # You can run the atom command multiple times, but after the first launch
  # the other launches will just pass their information to this server and then
  # close immediately.
  listenForArgumentsFromNewProcess: ->
    return unless @socketPath?
    @deleteSocketFile()
    server = net.createServer (connection) =>
      data = ''
      connection.on 'data', (chunk) ->
        data = data + chunk

      connection.on 'end', =>
        options = JSON.parse(data)
        @openWithOptions(options)

    server.listen @socketPath
    server.on 'error', (error) -> console.error 'Application server failed', error

  deleteSocketFile: ->
    return if process.platform is 'win32' or not @socketPath?

    if fs.existsSync(@socketPath)
      try
        fs.unlinkSync(@socketPath)
      catch error
        # Ignore ENOENT errors in case the file was deleted between the exists
        # check and the call to unlink sync. This occurred occasionally on CI
        # which is why this check is here.
        throw error unless error.code is 'ENOENT'

  # Registers basic application commands, non-idempotent.
  handleEvents: ->
    getLoadSettings = =>
      devMode: @focusedWindow()?.devMode
      safeMode: @focusedWindow()?.safeMode

    @on 'application:quit', -> app.quit()
    @on 'application:new-window', -> @openPath(getLoadSettings())
    @on 'application:new-file', -> (@focusedWindow() ? this).openPath()
    @on 'application:open-dev', -> @promptForPathToOpen('all', devMode: true)
    @on 'application:open-safe', -> @promptForPathToOpen('all', safeMode: true)
    @on 'application:inspect', ({x, y, atomWindow}) ->
      atomWindow ?= @focusedWindow()
      atomWindow?.browserWindow.inspectElement(x, y)

    @on 'application:open-documentation', -> shell.openExternal('http://flight-manual.atom.io/')
    @on 'application:open-discussions', -> shell.openExternal('https://discuss.atom.io')
    @on 'application:open-faq', -> shell.openExternal('https://atom.io/faq')
    @on 'application:open-terms-of-use', -> shell.openExternal('https://atom.io/terms')
    @on 'application:report-issue', -> shell.openExternal('https://github.com/atom/atom/blob/master/CONTRIBUTING.md#submitting-issues')
    @on 'application:search-issues', -> shell.openExternal('https://github.com/issues?q=+is%3Aissue+user%3Aatom')

    @on 'application:install-update', =>
      @quitting = true
      @autoUpdateManager.install()

    @on 'application:check-for-update', => @autoUpdateManager.check()

    if process.platform is 'darwin'
      @on 'application:bring-all-windows-to-front', -> Menu.sendActionToFirstResponder('arrangeInFront:')
      @on 'application:hide', -> Menu.sendActionToFirstResponder('hide:')
      @on 'application:hide-other-applications', -> Menu.sendActionToFirstResponder('hideOtherApplications:')
      @on 'application:minimize', -> Menu.sendActionToFirstResponder('performMiniaturize:')
      @on 'application:unhide-all-applications', -> Menu.sendActionToFirstResponder('unhideAllApplications:')
      @on 'application:zoom', -> Menu.sendActionToFirstResponder('zoom:')
    else
      @on 'application:minimize', -> @focusedWindow()?.minimize()
      @on 'application:zoom', -> @focusedWindow()?.maximize()

    @openPathOnEvent('application:about', 'atom://about')
    @openPathOnEvent('application:show-settings', 'atom://config')
    @openPathOnEvent('application:open-your-config', 'atom://.atom/config')
    @openPathOnEvent('application:open-your-init-script', 'atom://.atom/init-script')
    @openPathOnEvent('application:open-your-keymap', 'atom://.atom/keymap')
    @openPathOnEvent('application:open-your-snippets', 'atom://.atom/snippets')
    @openPathOnEvent('application:open-your-stylesheet', 'atom://.atom/stylesheet')
    @openPathOnEvent('application:open-license', path.join(process.resourcesPath, 'LICENSE.md'))

    @disposable.add ipcHelpers.on app, 'before-quit', (event) =>
      unless @quitting
        event.preventDefault()
        @quitting = true
        Promise.all(@windows.map((window) -> window.saveState())).then(-> app.quit())

    @disposable.add ipcHelpers.on app, 'will-quit', =>
      @killAllProcesses()
      @deleteSocketFile()

    @disposable.add ipcHelpers.on app, 'open-file', (event, pathToOpen) =>
      event.preventDefault()
      @openPath({pathToOpen})

    @disposable.add ipcHelpers.on app, 'open-url', (event, urlToOpen) =>
      event.preventDefault()
      @openUrl({urlToOpen, @devMode, @safeMode})

    @disposable.add ipcHelpers.on app, 'activate', (event, hasVisibleWindows) =>
      unless hasVisibleWindows
        event?.preventDefault()
        @emit('application:new-window')

    @disposable.add ipcHelpers.on ipcMain, 'restart-application', =>
      @restart()

    @disposable.add ipcHelpers.on ipcMain, 'resolve-proxy', (event, requestId, url) ->
      event.sender.session.resolveProxy url, (proxy) ->
        unless event.sender.isDestroyed()
          event.sender.send('did-resolve-proxy', requestId, proxy)

    @disposable.add ipcHelpers.on ipcMain, 'did-change-history-manager', (event) =>
      for atomWindow in @windows
        webContents = atomWindow.browserWindow.webContents
        if webContents isnt event.sender
          webContents.send('did-change-history-manager')

    # A request from the associated render process to open a new render process.
    @disposable.add ipcHelpers.on ipcMain, 'open', (event, options) =>
      window = @atomWindowForEvent(event)
      if options?
        if typeof options.pathsToOpen is 'string'
          options.pathsToOpen = [options.pathsToOpen]
        if options.pathsToOpen?.length > 0
          options.window = window
          @openPaths(options)
        else
          new AtomWindow(this, @fileRecoveryService, options)
      else
        @promptForPathToOpen('all', {window})

    @disposable.add ipcHelpers.on ipcMain, 'update-application-menu', (event, template, keystrokesByCommand) =>
      win = BrowserWindow.fromWebContents(event.sender)
      @applicationMenu?.update(win, template, keystrokesByCommand)

    @disposable.add ipcHelpers.on ipcMain, 'run-package-specs', (event, packageSpecPath) =>
      @runTests({resourcePath: @devResourcePath, pathsToOpen: [packageSpecPath], headless: false})

    @disposable.add ipcHelpers.on ipcMain, 'run-benchmarks', (event, benchmarksPath) =>
      @runBenchmarks({resourcePath: @devResourcePath, pathsToOpen: [benchmarksPath], headless: false, test: false})

    @disposable.add ipcHelpers.on ipcMain, 'command', (event, command) =>
      @emit(command)

    @disposable.add ipcHelpers.on ipcMain, 'open-command', (event, command, args...) =>
      defaultPath = args[0] if args.length > 0
      switch command
        when 'application:open' then @promptForPathToOpen('all', getLoadSettings(), defaultPath)
        when 'application:open-file' then @promptForPathToOpen('file', getLoadSettings(), defaultPath)
        when 'application:open-folder' then @promptForPathToOpen('folder', getLoadSettings(), defaultPath)
        else console.log "Invalid open-command received: " + command

    @disposable.add ipcHelpers.on ipcMain, 'window-command', (event, command, args...) ->
      win = BrowserWindow.fromWebContents(event.sender)
      win.emit(command, args...)

    @disposable.add ipcHelpers.respondTo 'window-method', (browserWindow, method, args...) =>
      @atomWindowForBrowserWindow(browserWindow)?[method](args...)

    @disposable.add ipcHelpers.on ipcMain, 'pick-folder', (event, responseChannel) =>
      @promptForPath "folder", (selectedPaths) ->
        event.sender.send(responseChannel, selectedPaths)

    @disposable.add ipcHelpers.respondTo 'set-window-size', (win, width, height) ->
      win.setSize(width, height)

    @disposable.add ipcHelpers.respondTo 'set-window-position', (win, x, y) ->
      win.setPosition(x, y)

    @disposable.add ipcHelpers.respondTo 'center-window', (win) ->
      win.center()

    @disposable.add ipcHelpers.respondTo 'focus-window', (win) ->
      win.focus()

    @disposable.add ipcHelpers.respondTo 'show-window', (win) ->
      win.show()

    @disposable.add ipcHelpers.respondTo 'hide-window', (win) ->
      win.hide()

    @disposable.add ipcHelpers.respondTo 'get-temporary-window-state', (win) ->
      win.temporaryState

    @disposable.add ipcHelpers.respondTo 'set-temporary-window-state', (win, state) ->
      win.temporaryState = state

    @disposable.add ipcHelpers.on ipcMain, 'did-cancel-window-unload', =>
      @quitting = false
      for window in @windows
        window.didCancelWindowUnload()

    clipboard = require '../safe-clipboard'
    @disposable.add ipcHelpers.on ipcMain, 'write-text-to-selection-clipboard', (event, selectedText) ->
      clipboard.writeText(selectedText, 'selection')

    @disposable.add ipcHelpers.on ipcMain, 'write-to-stdout', (event, output) ->
      process.stdout.write(output)

    @disposable.add ipcHelpers.on ipcMain, 'write-to-stderr', (event, output) ->
      process.stderr.write(output)

    @disposable.add ipcHelpers.on ipcMain, 'add-recent-document', (event, filename) ->
      app.addRecentDocument(filename)

    @disposable.add ipcHelpers.on ipcMain, 'execute-javascript-in-dev-tools', (event, code) ->
      event.sender.devToolsWebContents?.executeJavaScript(code)

    @disposable.add ipcHelpers.on ipcMain, 'get-auto-update-manager-state', (event) =>
      event.returnValue = @autoUpdateManager.getState()

    @disposable.add ipcHelpers.on ipcMain, 'get-auto-update-manager-error', (event) =>
      event.returnValue = @autoUpdateManager.getErrorMessage()

    @disposable.add ipcHelpers.on ipcMain, 'will-save-path', (event, path) =>
      @fileRecoveryService.willSavePath(@atomWindowForEvent(event), path)
      event.returnValue = true

    @disposable.add ipcHelpers.on ipcMain, 'did-save-path', (event, path) =>
      @fileRecoveryService.didSavePath(@atomWindowForEvent(event), path)
      event.returnValue = true

    @disposable.add ipcHelpers.on ipcMain, 'did-change-paths', =>
      @saveState(false)

    @disposable.add(@disableZoomOnDisplayChange())

  setupDockMenu: ->
    if process.platform is 'darwin'
      dockMenu = Menu.buildFromTemplate [
        {label: 'New Window',  click: => @emit('application:new-window')}
      ]
      app.dock.setMenu dockMenu

  # Public: Executes the given command.
  #
  # If it isn't handled globally, delegate to the currently focused window.
  #
  # command - The string representing the command.
  # args - The optional arguments to pass along.
  sendCommand: (command, args...) ->
    unless @emit(command, args...)
      focusedWindow = @focusedWindow()
      if focusedWindow?
        focusedWindow.sendCommand(command, args...)
      else
        @sendCommandToFirstResponder(command)

  # Public: Executes the given command on the given window.
  #
  # command - The string representing the command.
  # atomWindow - The {AtomWindow} to send the command to.
  # args - The optional arguments to pass along.
  sendCommandToWindow: (command, atomWindow, args...) ->
    unless @emit(command, args...)
      if atomWindow?
        atomWindow.sendCommand(command, args...)
      else
        @sendCommandToFirstResponder(command)

  # Translates the command into macOS action and sends it to application's first
  # responder.
  sendCommandToFirstResponder: (command) ->
    return false unless process.platform is 'darwin'

    switch command
      when 'core:undo' then Menu.sendActionToFirstResponder('undo:')
      when 'core:redo' then Menu.sendActionToFirstResponder('redo:')
      when 'core:copy' then Menu.sendActionToFirstResponder('copy:')
      when 'core:cut' then Menu.sendActionToFirstResponder('cut:')
      when 'core:paste' then Menu.sendActionToFirstResponder('paste:')
      when 'core:select-all' then Menu.sendActionToFirstResponder('selectAll:')
      else return false
    true

  # Public: Open the given path in the focused window when the event is
  # triggered.
  #
  # A new window will be created if there is no currently focused window.
  #
  # eventName - The event to listen for.
  # pathToOpen - The path to open when the event is triggered.
  openPathOnEvent: (eventName, pathToOpen) ->
    @on eventName, ->
      if window = @focusedWindow()
        window.openPath(pathToOpen)
      else
        @openPath({pathToOpen})

  # Returns the {AtomWindow} for the given paths.
  windowForPaths: (pathsToOpen, devMode) ->
    _.find @windows, (atomWindow) ->
      atomWindow.devMode is devMode and atomWindow.containsPaths(pathsToOpen)

  # Returns the {AtomWindow} for the given ipcMain event.
  atomWindowForEvent: ({sender}) ->
    @atomWindowForBrowserWindow(BrowserWindow.fromWebContents(sender))

  atomWindowForBrowserWindow: (browserWindow) ->
    @windows.find((atomWindow) -> atomWindow.browserWindow is browserWindow)

  # Public: Returns the currently focused {AtomWindow} or undefined if none.
  focusedWindow: ->
    _.find @windows, (atomWindow) -> atomWindow.isFocused()

  # Get the platform-specific window offset for new windows.
  getWindowOffsetForCurrentPlatform: ->
    offsetByPlatform =
      darwin: 22
      win32: 26
    offsetByPlatform[process.platform] ? 0

  # Get the dimensions for opening a new window by cascading as appropriate to
  # the platform.
  getDimensionsForNewWindow: ->
    return if (@focusedWindow() ? @lastFocusedWindow)?.isMaximized()
    dimensions = (@focusedWindow() ? @lastFocusedWindow)?.getDimensions()
    offset = @getWindowOffsetForCurrentPlatform()
    if dimensions? and offset?
      dimensions.x += offset
      dimensions.y += offset
    dimensions

  # Public: Opens a single path, in an existing window if possible.
  #
  # options -
  #   :pathToOpen - The file path to open
  #   :pidToKillWhenClosed - The integer of the pid to kill
  #   :newWindow - Boolean of whether this should be opened in a new window.
  #   :devMode - Boolean to control the opened window's dev mode.
  #   :safeMode - Boolean to control the opened window's safe mode.
  #   :profileStartup - Boolean to control creating a profile of the startup time.
  #   :window - {AtomWindow} to open file paths in.
  #   :addToLastWindow - Boolean of whether this should be opened in last focused window.
  openPath: ({initialPaths, pathToOpen, pidToKillWhenClosed, newWindow, devMode, safeMode, profileStartup, window, clearWindowState, addToLastWindow, env} = {}) ->
    @openPaths({initialPaths, pathsToOpen: [pathToOpen], pidToKillWhenClosed, newWindow, devMode, safeMode, profileStartup, window, clearWindowState, addToLastWindow, env})

  # Public: Opens multiple paths, in existing windows if possible.
  #
  # options -
  #   :pathsToOpen - The array of file paths to open
  #   :pidToKillWhenClosed - The integer of the pid to kill
  #   :newWindow - Boolean of whether this should be opened in a new window.
  #   :devMode - Boolean to control the opened window's dev mode.
  #   :safeMode - Boolean to control the opened window's safe mode.
  #   :windowDimensions - Object with height and width keys.
  #   :window - {AtomWindow} to open file paths in.
  #   :addToLastWindow - Boolean of whether this should be opened in last focused window.
  openPaths: ({initialPaths, pathsToOpen, executedFrom, pidToKillWhenClosed, newWindow, devMode, safeMode, windowDimensions, profileStartup, window, clearWindowState, addToLastWindow, env}={}) ->
    if not pathsToOpen? or pathsToOpen.length is 0
      return
    env = process.env unless env?
    devMode = Boolean(devMode)
    safeMode = Boolean(safeMode)
    clearWindowState = Boolean(clearWindowState)
    locationsToOpen = (@locationForPathToOpen(pathToOpen, executedFrom, addToLastWindow) for pathToOpen in pathsToOpen)
    pathsToOpen = (locationToOpen.pathToOpen for locationToOpen in locationsToOpen)

    unless pidToKillWhenClosed or newWindow
      existingWindow = @windowForPaths(pathsToOpen, devMode)
      stats = (fs.statSyncNoException(pathToOpen) for pathToOpen in pathsToOpen)
      unless existingWindow?
        if currentWindow = window ? @lastFocusedWindow
          existingWindow = currentWindow if (
            addToLastWindow or
            currentWindow.devMode is devMode and
            (
              stats.every((stat) -> stat.isFile?()) or
              stats.some((stat) -> stat.isDirectory?() and not currentWindow.hasProjectPath())
            )
          )

    if existingWindow?
      openedWindow = existingWindow
      openedWindow.openLocations(locationsToOpen)
      if openedWindow.isMinimized()
        openedWindow.restore()
      else
        openedWindow.focus()
      openedWindow.replaceEnvironment(env)
    else
      if devMode
        try
          windowInitializationScript = require.resolve(path.join(@devResourcePath, 'src', 'initialize-application-window'))
          resourcePath = @devResourcePath

      windowInitializationScript ?= require.resolve('../initialize-application-window')
      resourcePath ?= @resourcePath
      windowDimensions ?= @getDimensionsForNewWindow()
      openedWindow = new AtomWindow(this, @fileRecoveryService, {initialPaths, locationsToOpen, windowInitializationScript, resourcePath, devMode, safeMode, windowDimensions, profileStartup, clearWindowState, env})
      openedWindow.focus()
      @lastFocusedWindow = openedWindow

    if pidToKillWhenClosed?
      @pidsToOpenWindows[pidToKillWhenClosed] = openedWindow

    openedWindow.browserWindow.once 'closed', =>
      @killProcessForWindow(openedWindow)

    openedWindow

  # Kill all processes associated with opened windows.
  killAllProcesses: ->
    @killProcess(pid) for pid of @pidsToOpenWindows
    return

  # Kill process associated with the given opened window.
  killProcessForWindow: (openedWindow) ->
    for pid, trackedWindow of @pidsToOpenWindows
      @killProcess(pid) if trackedWindow is openedWindow
    return

  # Kill the process with the given pid.
  killProcess: (pid) ->
    try
      parsedPid = parseInt(pid)
      process.kill(parsedPid) if isFinite(parsedPid)
    catch error
      if error.code isnt 'ESRCH'
        console.log("Killing process #{pid} failed: #{error.code ? error.message}")
    delete @pidsToOpenWindows[pid]

  saveState: (allowEmpty=false) ->
    return if @quitting
    states = []
    for window in @windows
      unless window.isSpec
        states.push({initialPaths: window.representedDirectoryPaths})
    if states.length > 0 or allowEmpty
      @storageFolder.storeSync('application.json', states)
      @emit('application:did-save-state')

  loadState: (options) ->
    if (@config.get('core.restorePreviousWindowsOnStart') in ['yes', 'always']) and (states = @storageFolder.load('application.json'))?.length > 0
      for state in states
        @openWithOptions(Object.assign(options, {
          initialPaths: state.initialPaths
          pathsToOpen: state.initialPaths.filter (directoryPath) -> fs.isDirectorySync(directoryPath)
          urlsToOpen: []
          devMode: @devMode
          safeMode: @safeMode
        }))
    else
      null

  # Open an atom:// url.
  #
  # The host of the URL being opened is assumed to be the package name
  # responsible for opening the URL.  A new window will be created with
  # that package's `urlMain` as the bootstrap script.
  #
  # options -
  #   :urlToOpen - The atom:// url to open.
  #   :devMode - Boolean to control the opened window's dev mode.
  #   :safeMode - Boolean to control the opened window's safe mode.
  openUrl: ({urlToOpen, devMode, safeMode, env}) ->
    unless @packages?
      PackageManager = require '../package-manager'
      @packages = new PackageManager()
      @packages.initialize
        configDirPath: process.env.ATOM_HOME
        devMode: devMode
        resourcePath: @resourcePath

    packageName = url.parse(urlToOpen).host
    pack = _.find @packages.getAvailablePackageMetadata(), ({name}) -> name is packageName
    if pack?
      if pack.urlMain
        packagePath = @packages.resolvePackagePath(packageName)
        windowInitializationScript = path.resolve(packagePath, pack.urlMain)
        windowDimensions = @getDimensionsForNewWindow()
        new AtomWindow(this, @fileRecoveryService, {windowInitializationScript, @resourcePath, devMode, safeMode, urlToOpen, windowDimensions, env})
      else
        console.log "Package '#{pack.name}' does not have a url main: #{urlToOpen}"
    else
      console.log "Opening unknown url: #{urlToOpen}"

  # Opens up a new {AtomWindow} to run specs within.
  #
  # options -
  #   :headless - A Boolean that, if true, will close the window upon
  #                   completion.
  #   :resourcePath - The path to include specs from.
  #   :specPath - The directory to load specs from.
  #   :safeMode - A Boolean that, if true, won't run specs from ~/.atom/packages
  #               and ~/.atom/dev/packages, defaults to false.
  runTests: ({headless, resourcePath, executedFrom, pathsToOpen, logFile, safeMode, timeout, env}) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    timeoutInSeconds = Number.parseFloat(timeout)
    unless Number.isNaN(timeoutInSeconds)
      timeoutHandler = ->
        console.log "The test suite has timed out because it has been running for more than #{timeoutInSeconds} seconds."
        process.exit(124) # Use the same exit code as the UNIX timeout util.
      setTimeout(timeoutHandler, timeoutInSeconds * 1000)

    try
      windowInitializationScript = require.resolve(path.resolve(@devResourcePath, 'src', 'initialize-test-window'))
    catch error
      windowInitializationScript = require.resolve(path.resolve(__dirname, '..', '..', 'src', 'initialize-test-window'))

    testPaths = []
    if pathsToOpen?
      for pathToOpen in pathsToOpen
        testPaths.push(path.resolve(executedFrom, fs.normalize(pathToOpen)))

    if testPaths.length is 0
      process.stderr.write 'Error: Specify at least one test path\n\n'
      process.exit(1)

    legacyTestRunnerPath = @resolveLegacyTestRunnerPath()
    testRunnerPath = @resolveTestRunnerPath(testPaths[0])
    devMode = true
    isSpec = true
    safeMode ?= false
    new AtomWindow(this, @fileRecoveryService, {windowInitializationScript, resourcePath, headless, isSpec, devMode, testRunnerPath, legacyTestRunnerPath, testPaths, logFile, safeMode, env})

  runBenchmarks: ({headless, test, resourcePath, executedFrom, pathsToOpen, env}) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    try
      windowInitializationScript = require.resolve(path.resolve(@devResourcePath, 'src', 'initialize-benchmark-window'))
    catch error
      windowInitializationScript = require.resolve(path.resolve(__dirname, '..', '..', 'src', 'initialize-benchmark-window'))

    benchmarkPaths = []
    if pathsToOpen?
      for pathToOpen in pathsToOpen
        benchmarkPaths.push(path.resolve(executedFrom, fs.normalize(pathToOpen)))

    if benchmarkPaths.length is 0
      process.stderr.write 'Error: Specify at least one benchmark path.\n\n'
      process.exit(1)

    devMode = true
    isSpec = true
    safeMode = false
    new AtomWindow(this, @fileRecoveryService, {windowInitializationScript, resourcePath, headless, test, isSpec, devMode, benchmarkPaths, safeMode, env})

  resolveTestRunnerPath: (testPath) ->
    FindParentDir ?= require 'find-parent-dir'

    if packageRoot = FindParentDir.sync(testPath, 'package.json')
      packageMetadata = require(path.join(packageRoot, 'package.json'))
      if packageMetadata.atomTestRunner
        Resolve ?= require('resolve')
        if testRunnerPath = Resolve.sync(packageMetadata.atomTestRunner, basedir: packageRoot, extensions: Object.keys(require.extensions))
          return testRunnerPath
        else
          process.stderr.write "Error: Could not resolve test runner path '#{packageMetadata.atomTestRunner}'"
          process.exit(1)

    @resolveLegacyTestRunnerPath()

  resolveLegacyTestRunnerPath: ->
    try
      require.resolve(path.resolve(@devResourcePath, 'spec', 'jasmine-test-runner'))
    catch error
      require.resolve(path.resolve(__dirname, '..', '..', 'spec', 'jasmine-test-runner'))

  locationForPathToOpen: (pathToOpen, executedFrom='', forceAddToWindow) ->
    return {pathToOpen} unless pathToOpen

    pathToOpen = pathToOpen.replace(/[:\s]+$/, '')
    match = pathToOpen.match(LocationSuffixRegExp)

    if match?
      pathToOpen = pathToOpen.slice(0, -match[0].length)
      initialLine = Math.max(0, parseInt(match[1].slice(1)) - 1) if match[1]
      initialColumn = Math.max(0, parseInt(match[2].slice(1)) - 1) if match[2]
    else
      initialLine = initialColumn = null

    unless url.parse(pathToOpen).protocol?
      pathToOpen = path.resolve(executedFrom, fs.normalize(pathToOpen))

    {pathToOpen, initialLine, initialColumn, forceAddToWindow}

  # Opens a native dialog to prompt the user for a path.
  #
  # Once paths are selected, they're opened in a new or existing {AtomWindow}s.
  #
  # options -
  #   :type - A String which specifies the type of the dialog, could be 'file',
  #           'folder' or 'all'. The 'all' is only available on macOS.
  #   :devMode - A Boolean which controls whether any newly opened windows
  #              should be in dev mode or not.
  #   :safeMode - A Boolean which controls whether any newly opened windows
  #               should be in safe mode or not.
  #   :window - An {AtomWindow} to use for opening a selected file path.
  #   :path - An optional String which controls the default path to which the
  #           file dialog opens.
  promptForPathToOpen: (type, {devMode, safeMode, window}, path=null) ->
    @promptForPath type, ((pathsToOpen) =>
      @openPaths({pathsToOpen, devMode, safeMode, window})), path

  promptForPath: (type, callback, path) ->
    properties =
      switch type
        when 'file' then ['openFile']
        when 'folder' then ['openDirectory']
        when 'all' then ['openFile', 'openDirectory']
        else throw new Error("#{type} is an invalid type for promptForPath")

    # Show the open dialog as child window on Windows and Linux, and as
    # independent dialog on macOS. This matches most native apps.
    parentWindow =
      if process.platform is 'darwin'
        null
      else
        BrowserWindow.getFocusedWindow()

    openOptions =
      properties: properties.concat(['multiSelections', 'createDirectory'])
      title: switch type
        when 'file' then 'Open File'
        when 'folder' then 'Open Folder'
        else 'Open'

    # File dialog defaults to project directory of currently active editor
    if path?
      openOptions.defaultPath = path

    dialog.showOpenDialog(parentWindow, openOptions, callback)

  promptForRestart: ->
    chosen = dialog.showMessageBox BrowserWindow.getFocusedWindow(),
      type: 'warning'
      title: 'Restart required'
      message: "You will need to restart Atom for this change to take effect."
      buttons: ['Restart Atom', 'Cancel']
    if chosen is 0
      @restart()

  restart: ->
    args = []
    args.push("--safe") if @safeMode
    args.push("--log-file=#{@logFile}") if @logFile?
    args.push("--socket-path=#{@socketPath}") if @socketPath?
    args.push("--user-data-dir=#{@userDataDir}") if @userDataDir?
    if @devMode
      args.push('--dev')
      args.push("--resource-path=#{@resourcePath}")
    app.relaunch({args})
    app.quit()

  disableZoomOnDisplayChange: ->
    outerCallback = =>
      for window in @windows
        window.disableZoom()

    # Set the limits every time a display is added or removed, otherwise the
    # configuration gets reset to the default, which allows zooming the
    # webframe.
    screen.on('display-added', outerCallback)
    screen.on('display-removed', outerCallback)
    new Disposable ->
      screen.removeListener('display-added', outerCallback)
      screen.removeListener('display-removed', outerCallback)
