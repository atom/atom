AtomWindow = require './atom-window'
ApplicationMenu = require './application-menu'
AtomProtocolHandler = require './atom-protocol-handler'
AutoUpdateManager = require './auto-update-manager'
BrowserWindow = require 'browser-window'
StorageFolder = require '../storage-folder'
Menu = require 'menu'
app = require 'app'
dialog = require 'dialog'
shell = require 'shell'
fs = require 'fs-plus'
ipc = require 'ipc'
path = require 'path'
os = require 'os'
net = require 'net'
url = require 'url'
{EventEmitter} = require 'events'
_ = require 'underscore-plus'

DefaultSocketPath =
  if process.platform is 'win32'
    '\\\\.\\pipe\\atom-sock'
  else
    path.join(os.tmpdir(), "atom-#{process.env.USER}.sock")

# The application's singleton class.
#
# It's the entry point into the Atom application and maintains the global state
# of the application.
#
module.exports =
class AtomApplication
  _.extend @prototype, EventEmitter.prototype

  # Public: The entry point into the Atom application.
  @open: (options) ->
    options.socketPath ?= DefaultSocketPath

    createAtomApplication = -> new AtomApplication(options)

    # FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    # take a few seconds to trigger 'error' event, it could be a bug of node
    # or atom-shell, before it's fixed we check the existence of socketPath to
    # speedup startup.
    if (process.platform isnt 'win32' and not fs.existsSync options.socketPath) or options.test
      createAtomApplication()
      return

    client = net.connect {path: options.socketPath}, ->
      client.write JSON.stringify(options), ->
        client.end()
        app.terminate()

    client.on 'error', createAtomApplication

  windows: null
  applicationMenu: null
  atomProtocolHandler: null
  resourcePath: null
  version: null
  quitting: false

  exit: (status) -> app.exit(status)

  constructor: (options) ->
    {@resourcePath, @version, @devMode, @safeMode, @socketPath} = options

    # Normalize to make sure drive letter case is consistent on Windows
    @resourcePath = path.normalize(@resourcePath) if @resourcePath

    global.atomApplication = this

    @pidsToOpenWindows = {}
    @pathsToOpen ?= []
    @windows = []

    @autoUpdateManager = new AutoUpdateManager(@version, options.test)
    @applicationMenu = new ApplicationMenu(@version, @autoUpdateManager)
    @atomProtocolHandler = new AtomProtocolHandler(@resourcePath, @safeMode)

    @listenForArgumentsFromNewProcess()
    @setupJavaScriptArguments()
    @handleEvents()
    @storageFolder = new StorageFolder(process.env.ATOM_HOME)

    if options.pathsToOpen?.length > 0 or options.urlsToOpen?.length > 0 or options.test
      @openWithOptions(options)
    else
      @loadState() or @openPath(options)

  openWithOptions: ({pathsToOpen, urlsToOpen, test, pidToKillWhenClosed, devMode, safeMode, newWindow, specDirectory, logFile, profileStartup}) ->
    if test
      @runSpecs({exitWhenDone: true, @resourcePath, specDirectory, logFile})
    else if pathsToOpen.length > 0
      @openPaths({pathsToOpen, pidToKillWhenClosed, newWindow, devMode, safeMode, profileStartup})
    else if urlsToOpen.length > 0
      @openUrl({urlToOpen, devMode, safeMode}) for urlToOpen in urlsToOpen
    else
      # Always open a editor window if this is the first instance of Atom.
      @openPath({pidToKillWhenClosed, newWindow, devMode, safeMode, profileStartup})

  # Public: Removes the {AtomWindow} from the global window list.
  removeWindow: (window) ->
    if @windows.length is 1
      @applicationMenu?.enableWindowSpecificItems(false)
      if process.platform in ['win32', 'linux']
        app.quit()
        return
    @windows.splice(@windows.indexOf(window), 1)
    @saveState(true) unless window.isSpec

  # Public: Adds the {AtomWindow} to the global window list.
  addWindow: (window) ->
    @windows.push window
    @applicationMenu?.addWindow(window.browserWindow)
    window.once 'window:loaded', =>
      @autoUpdateManager.emitUpdateAvailableEvent(window)

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
    @deleteSocketFile()
    server = net.createServer (connection) =>
      connection.on 'data', (data) =>
        @openWithOptions(JSON.parse(data))

    server.listen @socketPath
    server.on 'error', (error) -> console.error 'Application server failed', error

  deleteSocketFile: ->
    return if process.platform is 'win32'

    if fs.existsSync(@socketPath)
      try
        fs.unlinkSync(@socketPath)
      catch error
        # Ignore ENOENT errors in case the file was deleted between the exists
        # check and the call to unlink sync. This occurred occasionally on CI
        # which is why this check is here.
        throw error unless error.code is 'ENOENT'

  # Configures required javascript environment flags.
  setupJavaScriptArguments: ->
    app.commandLine.appendSwitch 'js-flags', '--harmony'

  # Registers basic application commands, non-idempotent.
  handleEvents: ->
    getLoadSettings = =>
      devMode: @focusedWindow()?.devMode
      safeMode: @focusedWindow()?.safeMode

    @on 'application:run-all-specs', -> @runSpecs(exitWhenDone: false, resourcePath: global.devResourcePath, safeMode: @focusedWindow()?.safeMode)
    @on 'application:run-benchmarks', -> @runBenchmarks()
    @on 'application:quit', -> app.quit()
    @on 'application:new-window', -> @openPath(_.extend(windowDimensions: @focusedWindow()?.getDimensions(), getLoadSettings()))
    @on 'application:new-file', -> (@focusedWindow() ? this).openPath()
    @on 'application:open', -> @promptForPathToOpen('all', getLoadSettings())
    @on 'application:open-file', -> @promptForPathToOpen('file', getLoadSettings())
    @on 'application:open-folder', -> @promptForPathToOpen('folder', getLoadSettings())
    @on 'application:open-dev', -> @promptForPathToOpen('all', devMode: true)
    @on 'application:open-safe', -> @promptForPathToOpen('all', safeMode: true)
    @on 'application:inspect', ({x, y, atomWindow}) ->
      atomWindow ?= @focusedWindow()
      atomWindow?.browserWindow.inspectElement(x, y)

    @on 'application:open-documentation', -> shell.openExternal('https://atom.io/docs/latest/?app')
    @on 'application:open-discussions', -> shell.openExternal('https://discuss.atom.io')
    @on 'application:open-roadmap', -> shell.openExternal('https://atom.io/roadmap?app')
    @on 'application:open-faq', -> shell.openExternal('https://atom.io/faq')
    @on 'application:open-terms-of-use', -> shell.openExternal('https://atom.io/terms')
    @on 'application:report-issue', -> shell.openExternal('https://github.com/atom/atom/blob/master/CONTRIBUTING.md#submitting-issues')
    @on 'application:search-issues', -> shell.openExternal('https://github.com/issues?q=+is%3Aissue+user%3Aatom')

    @on 'application:install-update', =>
      @quitting = true
      @autoUpdateManager.install()

    @on 'application:check-for-update', => @autoUpdateManager.check()

    if process.platform is 'darwin'
      @on 'application:about', -> Menu.sendActionToFirstResponder('orderFrontStandardAboutPanel:')
      @on 'application:bring-all-windows-to-front', -> Menu.sendActionToFirstResponder('arrangeInFront:')
      @on 'application:hide', -> Menu.sendActionToFirstResponder('hide:')
      @on 'application:hide-other-applications', -> Menu.sendActionToFirstResponder('hideOtherApplications:')
      @on 'application:minimize', -> Menu.sendActionToFirstResponder('performMiniaturize:')
      @on 'application:unhide-all-applications', -> Menu.sendActionToFirstResponder('unhideAllApplications:')
      @on 'application:zoom', -> Menu.sendActionToFirstResponder('zoom:')
    else
      @on 'application:minimize', -> @focusedWindow()?.minimize()
      @on 'application:zoom', -> @focusedWindow()?.maximize()

    @openPathOnEvent('application:show-settings', 'atom://config')
    @openPathOnEvent('application:open-your-config', 'atom://.atom/config')
    @openPathOnEvent('application:open-your-init-script', 'atom://.atom/init-script')
    @openPathOnEvent('application:open-your-keymap', 'atom://.atom/keymap')
    @openPathOnEvent('application:open-your-snippets', 'atom://.atom/snippets')
    @openPathOnEvent('application:open-your-stylesheet', 'atom://.atom/stylesheet')
    @openPathOnEvent('application:open-license', path.join(process.resourcesPath, 'LICENSE.md'))

    app.on 'before-quit', =>
      @saveState(false)
      @quitting = true

    app.on 'will-quit', =>
      @killAllProcesses()
      @deleteSocketFile()

    app.on 'will-exit', =>
      @saveState(false)
      @killAllProcesses()
      @deleteSocketFile()

    app.on 'open-file', (event, pathToOpen) =>
      event.preventDefault()
      @openPath({pathToOpen})

    app.on 'open-url', (event, urlToOpen) =>
      event.preventDefault()
      @openUrl({urlToOpen, @devMode, @safeMode})

    app.on 'activate-with-no-open-windows', (event) =>
      event.preventDefault()
      @emit('application:new-window')

    # A request from the associated render process to open a new render process.
    ipc.on 'open', (event, options) =>
      window = @windowForEvent(event)
      if options?
        if typeof options.pathsToOpen is 'string'
          options.pathsToOpen = [options.pathsToOpen]
        if options.pathsToOpen?.length > 0
          options.window = window
          @openPaths(options)
        else
          new AtomWindow(options)
      else
        @promptForPathToOpen('all', {window})

    ipc.on 'update-application-menu', (event, template, keystrokesByCommand) =>
      win = BrowserWindow.fromWebContents(event.sender)
      @applicationMenu.update(win, template, keystrokesByCommand)

    ipc.on 'run-package-specs', (event, specDirectory) =>
      @runSpecs({resourcePath: global.devResourcePath, specDirectory: specDirectory, exitWhenDone: false})

    ipc.on 'command', (event, command) =>
      @emit(command)

    ipc.on 'window-command', (event, command, args...) ->
      win = BrowserWindow.fromWebContents(event.sender)
      win.emit(command, args...)

    ipc.on 'call-window-method', (event, method, args...) ->
      win = BrowserWindow.fromWebContents(event.sender)
      win[method](args...)

    ipc.on 'pick-folder', (event, responseChannel) =>
      @promptForPath "folder", (selectedPaths) ->
        event.sender.send(responseChannel, selectedPaths)

    ipc.on 'cancel-window-close', =>
      @quitting = false

    clipboard = require '../safe-clipboard'
    ipc.on 'write-text-to-selection-clipboard', (event, selectedText) ->
      clipboard.writeText(selectedText, 'selection')

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

  # Translates the command into OS X action and sends it to application's first
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

  # Returns the {AtomWindow} for the given ipc event.
  windowForEvent: ({sender}) ->
    window = BrowserWindow.fromWebContents(sender)
    _.find @windows, ({browserWindow}) -> window is browserWindow

  # Public: Returns the currently focused {AtomWindow} or undefined if none.
  focusedWindow: ->
    _.find @windows, (atomWindow) -> atomWindow.isFocused()

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
  openPath: ({pathToOpen, pidToKillWhenClosed, newWindow, devMode, safeMode, profileStartup, window}) ->
    @openPaths({pathsToOpen: [pathToOpen], pidToKillWhenClosed, newWindow, devMode, safeMode, profileStartup, window})

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
  openPaths: ({pathsToOpen, pidToKillWhenClosed, newWindow, devMode, safeMode, windowDimensions, profileStartup, window}={}) ->
    pathsToOpen = pathsToOpen.map (pathToOpen) ->
      if fs.existsSync(pathToOpen)
        fs.normalize(pathToOpen)
      else
        pathToOpen

    locationsToOpen = (@locationForPathToOpen(pathToOpen) for pathToOpen in pathsToOpen)

    unless pidToKillWhenClosed or newWindow
      existingWindow = @windowForPaths(pathsToOpen, devMode)

      # Default to using the specified window or the last focused window
      currentWindow = window ? @lastFocusedWindow
      stats = (fs.statSyncNoException(pathToOpen) for pathToOpen in pathsToOpen)
      existingWindow ?= currentWindow if (
        stats.every((stat) -> stat.isFile?()) or
        stats.some((stat) -> stat.isDirectory?()) and not currentWindow?.hasProjectPath()
      )

    if existingWindow?
      openedWindow = existingWindow
      openedWindow.openLocations(locationsToOpen)
      if openedWindow.isMinimized()
        openedWindow.restore()
      else
        openedWindow.focus()
    else
      if devMode
        try
          bootstrapScript = require.resolve(path.join(global.devResourcePath, 'src', 'window-bootstrap'))
          resourcePath = global.devResourcePath

      bootstrapScript ?= require.resolve('../window-bootstrap')
      resourcePath ?= @resourcePath
      openedWindow = new AtomWindow({locationsToOpen, bootstrapScript, resourcePath, devMode, safeMode, windowDimensions, profileStartup})

    if pidToKillWhenClosed?
      @pidsToOpenWindows[pidToKillWhenClosed] = openedWindow

    openedWindow.browserWindow.once 'closed', =>
      @killProcessForWindow(openedWindow)

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
        if loadSettings = window.getLoadSettings()
          states.push(initialPaths: loadSettings.initialPaths)
    if states.length > 0 or allowEmpty
      @storageFolder.store('application.json', states)

  loadState: ->
    if (states = @storageFolder.load('application.json'))?.length > 0
      for state in states
        @openWithOptions({
          pathsToOpen: state.initialPaths
          urlsToOpen: []
          devMode: @devMode
          safeMode: @safeMode
        })
      true
    else
      false

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
  openUrl: ({urlToOpen, devMode, safeMode}) ->
    unless @packages?
      PackageManager = require '../package-manager'
      @packages = new PackageManager
        configDirPath: process.env.ATOM_HOME
        devMode: devMode
        resourcePath: @resourcePath

    packageName = url.parse(urlToOpen).host
    pack = _.find @packages.getAvailablePackageMetadata(), ({name}) -> name is packageName
    if pack?
      if pack.urlMain
        packagePath = @packages.resolvePackagePath(packageName)
        bootstrapScript = path.resolve(packagePath, pack.urlMain)
        windowDimensions = @focusedWindow()?.getDimensions()
        new AtomWindow({bootstrapScript, @resourcePath, devMode, safeMode, urlToOpen, windowDimensions})
      else
        console.log "Package '#{pack.name}' does not have a url main: #{urlToOpen}"
    else
      console.log "Opening unknown url: #{urlToOpen}"

  # Opens up a new {AtomWindow} to run specs within.
  #
  # options -
  #   :exitWhenDone - A Boolean that, if true, will close the window upon
  #                   completion.
  #   :resourcePath - The path to include specs from.
  #   :specPath - The directory to load specs from.
  #   :safeMode - A Boolean that, if true, won't run specs from ~/.atom/packages
  #               and ~/.atom/dev/packages, defaults to false.
  runSpecs: ({exitWhenDone, resourcePath, specDirectory, logFile, safeMode}) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    try
      bootstrapScript = require.resolve(path.resolve(global.devResourcePath, 'spec', 'spec-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'spec', 'spec-bootstrap'))

    isSpec = true
    devMode = true
    safeMode ?= false
    new AtomWindow({bootstrapScript, resourcePath, exitWhenDone, isSpec, devMode, specDirectory, logFile, safeMode})

  runBenchmarks: ({exitWhenDone, specDirectory}={}) ->
    try
      bootstrapScript = require.resolve(path.resolve(global.devResourcePath, 'benchmark', 'benchmark-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'benchmark', 'benchmark-bootstrap'))

    specDirectory ?= path.dirname(bootstrapScript)

    isSpec = true
    devMode = true
    new AtomWindow({bootstrapScript, @resourcePath, exitWhenDone, isSpec, specDirectory, devMode})

  locationForPathToOpen: (pathToOpen) ->
    return {pathToOpen} unless pathToOpen
    return {pathToOpen} if url.parse(pathToOpen).protocol?
    return {pathToOpen} if fs.existsSync(pathToOpen)

    pathToOpen = pathToOpen.replace(/[:\s]+$/, '')

    [fileToOpen, initialLine, initialColumn] = path.basename(pathToOpen).split(':')
    return {pathToOpen} unless initialLine
    return {pathToOpen} unless parseInt(initialLine) >= 0

    # Convert line numbers to a base of 0
    initialLine = Math.max(0, initialLine - 1) if initialLine
    initialColumn = Math.max(0, initialColumn - 1) if initialColumn
    pathToOpen = path.join(path.dirname(pathToOpen), fileToOpen)
    {pathToOpen, initialLine, initialColumn}

  # Opens a native dialog to prompt the user for a path.
  #
  # Once paths are selected, they're opened in a new or existing {AtomWindow}s.
  #
  # options -
  #   :type - A String which specifies the type of the dialog, could be 'file',
  #           'folder' or 'all'. The 'all' is only available on OS X.
  #   :devMode - A Boolean which controls whether any newly opened windows
  #              should be in dev mode or not.
  #   :safeMode - A Boolean which controls whether any newly opened windows
  #               should be in safe mode or not.
  #   :window - An {AtomWindow} to use for opening a selected file path.
  promptForPathToOpen: (type, {devMode, safeMode, window}) ->
    @promptForPath type, (pathsToOpen) =>
      @openPaths({pathsToOpen, devMode, safeMode, window})

  promptForPath: (type, callback) ->
    properties =
      switch type
        when 'file' then ['openFile']
        when 'folder' then ['openDirectory']
        when 'all' then ['openFile', 'openDirectory']
        else throw new Error("#{type} is an invalid type for promptForPath")

    # Show the open dialog as child window on Windows and Linux, and as
    # independent dialog on OS X. This matches most native apps.
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

    if process.platform is 'linux'
      if projectPath = @lastFocusedWindow?.projectPath
        openOptions.defaultPath = projectPath

    dialog.showOpenDialog(parentWindow, openOptions, callback)
