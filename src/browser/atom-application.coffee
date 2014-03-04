AtomWindow = require './atom-window'
ApplicationMenu = require './application-menu'
AtomProtocolHandler = require './atom-protocol-handler'
BrowserWindow = require 'browser-window'
Menu = require 'menu'
autoUpdater = require 'auto-updater'
app = require 'app'
dialog = require 'dialog'
fs = require 'fs'
ipc = require 'ipc'
path = require 'path'
os = require 'os'
net = require 'net'
shell = require 'shell'
url = require 'url'
{EventEmitter} = require 'events'
_ = require 'underscore-plus'

socketPath =
  if process.platform is 'win32'
    '\\\\.\\pipe\\atom-sock'
  else
    path.join(os.tmpdir(), 'atom.sock')

# The application's singleton class.
#
# It's the entry point into the Atom application and maintains the global state
# of the application.
#
module.exports =
class AtomApplication
  _.extend @prototype, EventEmitter.prototype
  updateVersion: null

  # Public: The entry point into the Atom application.
  @open: (options) ->
    createAtomApplication = -> new AtomApplication(options)

    # FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    # take a few seconds to trigger 'error' event, it could be a bug of node
    # or atom-shell, before it's fixed we check the existence of socketPath to
    # speedup startup.
    if (process.platform isnt 'win32' and not fs.existsSync socketPath) or options.test
      createAtomApplication()
      return

    client = net.connect {path: socketPath}, ->
      client.write JSON.stringify(options), ->
        client.end()
        app.terminate()

    client.on 'error', createAtomApplication

  windows: null
  applicationMenu: null
  atomProtocolHandler: null
  resourcePath: null
  version: null

  exit: (status) -> app.exit(status)

  constructor: (options) ->
    {@resourcePath, @version, @devMode} = options
    global.atomApplication = this

    @pidsToOpenWindows = {}
    @pathsToOpen ?= []
    @windows = []

    @applicationMenu = new ApplicationMenu(@version)
    @atomProtocolHandler = new AtomProtocolHandler(@resourcePath)

    @listenForArgumentsFromNewProcess()
    @setupJavaScriptArguments()
    @handleEvents()
    @setupAutoUpdater()

    @openWithOptions(options)

  # Opens a new window based on the options provided.
  openWithOptions: ({pathsToOpen, urlsToOpen, test, pidToKillWhenClosed, devMode, newWindow, specDirectory, logFile}) ->
    if test
      @runSpecs({exitWhenDone: true, @resourcePath, specDirectory, logFile})
    else if pathsToOpen.length > 0
      @openPaths({pathsToOpen, pidToKillWhenClosed, newWindow, devMode})
    else if urlsToOpen.length > 0
      @openUrl({urlToOpen, devMode}) for urlToOpen in urlsToOpen
    else
      @openPath({pidToKillWhenClosed, newWindow, devMode}) # Always open a editor window if this is the first instance of Atom.

  # Public: Removes the {AtomWindow} from the global window list.
  removeWindow: (window) ->
    @windows.splice @windows.indexOf(window), 1
    @applicationMenu?.enableWindowSpecificItems(false) if @windows.length == 0

  # Public: Adds the {AtomWindow} to the global window list.
  addWindow: (window) ->
    @windows.push window
    @applicationMenu?.enableWindowSpecificItems(true)

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

    server.listen socketPath
    server.on 'error', (error) -> console.error 'Application server failed', error

  deleteSocketFile: ->
    return if process.platform is 'win32'

    if fs.existsSync(socketPath)
      try
        fs.unlinkSync(socketPath)
      catch error
        # Ignore ENOENT errors in case the file was deleted between the exists
        # check and the call to unlink sync. This occurred occasionally on CI
        # which is why this check is here.
        throw error unless error.code is 'ENOENT'

  # Configures required javascript environment flags.
  setupJavaScriptArguments: ->
    app.commandLine.appendSwitch 'js-flags', '--harmony_collections --harmony-proxies'

  # Enable updates unless running from a local build of Atom.
  setupAutoUpdater: ->
    autoUpdater.setFeedUrl "https://atom.io/api/updates?version=#{@version}"

    autoUpdater.on 'checking-for-update', =>
      @applicationMenu.showDownloadingUpdateItem(false)
      @applicationMenu.showInstallUpdateItem(false)
      @applicationMenu.showCheckForUpdateItem(false)

    autoUpdater.on 'update-not-available', =>
      @applicationMenu.showCheckForUpdateItem(true)

    autoUpdater.on 'update-available', =>
      @applicationMenu.showDownloadingUpdateItem(true)

    autoUpdater.on 'update-downloaded', (event, releaseNotes, releaseName, releaseDate, releaseURL) =>
      atomWindow.sendCommand('window:update-available', [releaseName, releaseNotes]) for atomWindow in @windows
      @applicationMenu.showInstallUpdateItem(true)
      @updateVersion = releaseName

    autoUpdater.on 'error', (event, message) =>
      @applicationMenu.showCheckForUpdateItem(true)

    # Check for update after Atom has fully started and the menus are created
    setTimeout((-> autoUpdater.checkForUpdates()), 5000)

  checkForUpdate: ->
    removeListeners = =>
      autoUpdater.removeListener 'update-not-available', @onUpdateNotAvailable
      autoUpdater.removeListener 'error', @onUpdateError

    @onUpdateNotAvailable ?= =>
      removeListeners()
      dialog.showMessageBox type: 'info', buttons: ['OK'], message: 'No update available.', detail: "Version #{@version} is the latest version."

    @onUpdateError ?= (event, message) =>
      removeListeners()
      dialog.showMessageBox type: 'warning', buttons: ['OK'], message: 'There was an error checking for updates.', detail: message

    autoUpdater.on 'update-not-available', @onUpdateNotAvailable
    autoUpdater.on 'error', @onUpdateError
    @applicationMenu.showCheckForUpdateItem(false)
    autoUpdater.checkForUpdates()

  # Registers basic application commands, non-idempotent.
  handleEvents: ->
    @on 'application:about', -> Menu.sendActionToFirstResponder('orderFrontStandardAboutPanel:')
    @on 'application:run-all-specs', -> @runSpecs(exitWhenDone: false, resourcePath: global.devResourcePath)
    @on 'application:run-benchmarks', -> @runBenchmarks()
    @on 'application:quit', -> app.quit()
    @on 'application:hide', -> Menu.sendActionToFirstResponder('hide:')
    @on 'application:hide-other-applications', -> Menu.sendActionToFirstResponder('hideOtherApplications:')
    @on 'application:unhide-all-applications', -> Menu.sendActionToFirstResponder('unhideAllApplications:')
    @on 'application:new-window', -> @openPath(initialSize: @getFocusedWindowSize())
    @on 'application:new-file', -> (@focusedWindow() ? this).openPath()
    @on 'application:open', -> @promptForPath()
    @on 'application:open-dev', -> @promptForPath(devMode: true)
    @on 'application:minimize', -> Menu.sendActionToFirstResponder('performMiniaturize:')
    @on 'application:zoom', -> Menu.sendActionToFirstResponder('zoom:')
    @on 'application:bring-all-windows-to-front', -> Menu.sendActionToFirstResponder('arrangeInFront:')
    @on 'application:inspect', ({x,y}) -> @focusedWindow().browserWindow.inspectElement(x, y)
    @on 'application:open-documentation', -> shell.openExternal('https://atom.io/docs/latest/?app')
    @on 'application:install-update', -> autoUpdater.quitAndInstall()
    @on 'application:check-for-update', => @checkForUpdate()

    @openPathOnEvent('application:show-settings', 'atom://config')
    @openPathOnEvent('application:open-your-config', 'atom://.atom/config')
    @openPathOnEvent('application:open-your-init-script', 'atom://.atom/init-script')
    @openPathOnEvent('application:open-your-keymap', 'atom://.atom/keymap')
    @openPathOnEvent('application:open-your-snippets', 'atom://.atom/snippets')
    @openPathOnEvent('application:open-your-stylesheet', 'atom://.atom/stylesheet')

    app.on 'window-all-closed', ->
      app.quit() if process.platform is 'win32'

    app.on 'will-quit', => @deleteSocketFile()
    app.on 'will-exit', => @deleteSocketFile()

    app.on 'open-file', (event, pathToOpen) =>
      event.preventDefault()
      @openPath({pathToOpen})

    app.on 'open-url', (event, urlToOpen) =>
      event.preventDefault()
      @openUrl({urlToOpen, @devMode})

    # A request from the associated render process to open a new render process.
    ipc.on 'open', (processId, routingId, options) =>
      if options?
        if options.pathsToOpen?.length > 0
          @openPaths(options)
        else
          new AtomWindow(options)
      else
        @promptForPath()

    ipc.on 'update-application-menu', (processId, routingId, template, keystrokesByCommand) =>
      @applicationMenu.update(template, keystrokesByCommand)

    ipc.on 'run-package-specs', (processId, routingId, specDirectory) =>
      @runSpecs({resourcePath: global.devResourcePath, specDirectory: specDirectory, exitWhenDone: false})

    ipc.on 'command', (processId, routingId, command) =>
      @emit(command)

    ipc.on 'window-command', (processId, routingId, command, args...) ->
      win = BrowserWindow.fromProcessIdAndRoutingId(processId, routingId)
      win.emit(command, args...)

    ipc.on 'call-window-method', (processId, routingId, method, args...) ->
      win = BrowserWindow.fromProcessIdAndRoutingId(processId, routingId)
      win[method](args...)

  # Public: Executes the given command.
  #
  # If it isn't handled globally, delegate to the currently focused window.
  #
  # * command:
  #   The string representing the command.
  # * args:
  #   The optional arguments to pass along.
  sendCommand: (command, args...) ->
    unless @emit(command, args...)
      @focusedWindow()?.sendCommand(command, args...)

  # Public: Open the given path in the focused window when the event is
  # triggered.
  #
  # A new window will be created if there is no currently focused window.
  #
  # * eventName: The event to listen for.
  # * pathToOpen: The path to open when the event is triggered.
  openPathOnEvent: (eventName, pathToOpen) ->
    @on eventName, ->
      if window = @focusedWindow()
        window.openPath(pathToOpen)
      else
        @openPath({pathToOpen})

  # Returns the {AtomWindow} for the given path.
  windowForPath: (pathToOpen) ->
    for atomWindow in @windows
      return atomWindow if atomWindow.containsPath(pathToOpen)

  # Public: Returns the currently focused {AtomWindow} or undefined if none.
  focusedWindow: ->
    _.find @windows, (atomWindow) -> atomWindow.isFocused()

  # Public: Get the height and width of the focused window.
  #
  # Returns an object with height and width keys or null if there is no
  # focused window.
  getFocusedWindowSize: ->
    if focusedWindow = @focusedWindow()
      [width, height] = focusedWindow.getSize()
      {width, height}
    else
      null

  # Public: Opens multiple paths, in existing windows if possible.
  #
  # * options
  #    + pathsToOpen:
  #      The array of file paths to open
  #    + pidToKillWhenClosed:
  #      The integer of the pid to kill
  #    + newWindow:
  #      Boolean of whether this should be opened in a new window.
  #    + devMode:
  #      Boolean to control the opened window's dev mode.
  openPaths: ({pathsToOpen, pidToKillWhenClosed, newWindow, devMode}) ->
    @openPath({pathToOpen, pidToKillWhenClosed, newWindow, devMode}) for pathToOpen in pathsToOpen ? []

  # Public: Opens a single path, in an existing window if possible.
  #
  # * options
  #    + pathToOpen:
  #      The file path to open
  #    + pidToKillWhenClosed:
  #      The integer of the pid to kill
  #    + newWindow:
  #      Boolean of whether this should be opened in a new window.
  #    + devMode:
  #      Boolean to control the opened window's dev mode.
  #    + initialSize:
  #      Object with height and width keys.
  openPath: ({pathToOpen, pidToKillWhenClosed, newWindow, devMode, initialSize}={}) ->
    if pathToOpen
      [basename, initialLine] = path.basename(pathToOpen).split(':')
      if initialLine
        pathToOpen = "#{path.dirname(pathToOpen)}/#{basename}"
        initialLine -= 1 # Convert line numbers to a base of 0

    unless devMode
      existingWindow = @windowForPath(pathToOpen) unless pidToKillWhenClosed or newWindow
    if existingWindow
      openedWindow = existingWindow
      openedWindow.openPath(pathToOpen, initialLine)
    else
      if devMode
        try
          bootstrapScript = require.resolve(path.join(global.devResourcePath, 'src', 'window-bootstrap'))
          resourcePath = global.devResourcePath

      bootstrapScript ?= require.resolve('../window-bootstrap')
      resourcePath ?= @resourcePath
      openedWindow = new AtomWindow({pathToOpen, initialLine, bootstrapScript, resourcePath, devMode, initialSize})

    if pidToKillWhenClosed?
      @pidsToOpenWindows[pidToKillWhenClosed] = openedWindow

    openedWindow.browserWindow.on 'destroyed', =>
      for pid, trackedWindow of @pidsToOpenWindows when trackedWindow is openedWindow
        try
          process.kill(pid)
        catch error
          if error.code isnt 'ESRCH'
            console.log("Killing process #{pid} failed: #{error.code}")
        delete @pidsToOpenWindows[pid]

  # Open an atom:// url.
  #
  # The host of the URL being opened is assumed to be the package name
  # responsible for opening the URL.  A new window will be created with
  # that package's `urlMain` as the bootstrap script.
  #
  # * options
  #    + urlToOpen:
  #      The atom:// url to open.
  #    + devMode:
  #      Boolean to control the opened window's dev mode.
  openUrl: ({urlToOpen, devMode}) ->
    unless @packages?
      PackageManager = require '../package-manager'
      fs = require 'fs-plus'
      @packages = new PackageManager
        configDirPath: fs.absolute('~/.atom')
        devMode: devMode
        resourcePath: @resourcePath

    packageName = url.parse(urlToOpen).host
    pack = _.find @packages.getAvailablePackageMetadata(), ({name}) -> name is packageName
    if pack?
      if pack.urlMain
        packagePath = @packages.resolvePackagePath(packageName)
        bootstrapScript = path.resolve(packagePath, pack.urlMain)
        new AtomWindow({bootstrapScript, @resourcePath, devMode, urlToOpen, initialSize: @getFocusedWindowSize()})
      else
        console.log "Package '#{pack.name}' does not have a url main: #{urlToOpen}"
    else
      console.log "Opening unknown url: #{urlToOpen}"

  # Opens up a new {AtomWindow} to run specs within.
  #
  # * options
  #    + exitWhenDone:
  #      A Boolean that if true, will close the window upon completion.
  #    + resourcePath:
  #      The path to include specs from.
  #    + specPath:
  #      The directory to load specs from.
  runSpecs: ({exitWhenDone, resourcePath, specDirectory, logFile}) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    try
      bootstrapScript = require.resolve(path.resolve(global.devResourcePath, 'spec', 'spec-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'spec', 'spec-bootstrap'))

    isSpec = true
    devMode = true
    new AtomWindow({bootstrapScript, resourcePath, exitWhenDone, isSpec, devMode, specDirectory, logFile})

  runBenchmarks: ->
    try
      bootstrapScript = require.resolve(path.resolve(global.devResourcePath, 'benchmark', 'benchmark-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'benchmark', 'benchmark-bootstrap'))

    isSpec = true
    new AtomWindow({bootstrapScript, @resourcePath, isSpec})

  # Opens a native dialog to prompt the user for a path.
  #
  # Once paths are selected, they're opened in a new or existing {AtomWindow}s.
  #
  # * options
  #    + devMode:
  #      A Boolean which controls whether any newly opened windows should  be in
  #      dev mode or not.
  promptForPath: ({devMode}={}) ->
    dialog.showOpenDialog title: 'Open', properties: ['openFile', 'openDirectory', 'multiSelections', 'createDirectory'], (pathsToOpen) =>
      @openPaths({pathsToOpen, devMode})

  # Public: If an update is available, it returns the new version string
  # otherwise it returns null.
  getUpdateVersion: ->
    @updateVersion
