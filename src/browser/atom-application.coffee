AtomWindow = require './atom-window'
ApplicationMenu = require './application-menu'
AtomProtocolHandler = require './atom-protocol-handler'
Menu = require 'menu'
autoUpdater = require 'auto-updater'
app = require 'app'
ipc = require 'ipc'
dialog = require 'dialog'
fs = require 'fs'
path = require 'path'
net = require 'net'
url = require 'url'
{EventEmitter} = require 'events'
_ = require 'underscore'

socketPath = '/tmp/atom.sock'

# Private: The application's singleton class.
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
    if (not fs.existsSync socketPath) or options.test
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
    @checkForUpdates()

    @openWithOptions(options)

  # Private: Opens a new window based on the options provided.
  openWithOptions: ({pathsToOpen, urlsToOpen, test, pidToKillWhenClosed, devMode, newWindow, specDirectory}) ->
    if test
      @runSpecs({exitWhenDone: true, @resourcePath, specDirectory})
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

  # Private: Creates server to listen for additional atom application launches.
  #
  # You can run the atom command multiple times, but after the first launch
  # the other launches will just pass their information to this server and then
  # close immediately.
  listenForArgumentsFromNewProcess: ->
    fs.unlinkSync socketPath if fs.existsSync(socketPath)
    server = net.createServer (connection) =>
      connection.on 'data', (data) =>
        @openWithOptions(JSON.parse(data))

    server.listen socketPath
    server.on 'error', (error) -> console.error 'Application server failed', error

  # Private: Configures required javascript environment flags.
  setupJavaScriptArguments: ->
    app.commandLine.appendSwitch 'js-flags', '--harmony_collections'

  # Private: Enable updates unless running from a local build of Atom.
  checkForUpdates: ->
    versionIsSha = /\w{7}/.test @version

    if versionIsSha
      autoUpdater.setAutomaticallyDownloadsUpdates false
      autoUpdater.setAutomaticallyChecksForUpdates false
    else
      autoUpdater.setAutomaticallyDownloadsUpdates true
      autoUpdater.setAutomaticallyChecksForUpdates true
      autoUpdater.checkForUpdatesInBackground()

  # Private: Registers basic application commands, non-idempotent.
  handleEvents: ->
    @on 'application:about', -> Menu.sendActionToFirstResponder('orderFrontStandardAboutPanel:')
    @on 'application:run-all-specs', -> @runSpecs(exitWhenDone: false, resourcePath: global.devResourcePath)
    @on 'application:run-benchmarks', -> @runBenchmarks()
    @on 'application:show-settings', -> (@focusedWindow() ? this).openPath("atom://config")
    @on 'application:quit', -> app.quit()
    @on 'application:hide', -> Menu.sendActionToFirstResponder('hide:')
    @on 'application:hide-other-applications', -> Menu.sendActionToFirstResponder('hideOtherApplications:')
    @on 'application:unhide-all-applications', -> Menu.sendActionToFirstResponder('unhideAllApplications:')
    @on 'application:new-window', ->
      @openPath(initialSize: @getFocusedWindowSize())
    @on 'application:new-file', -> (@focusedWindow() ? this).openPath()
    @on 'application:open', -> @promptForPath()
    @on 'application:open-dev', -> @promptForPath(devMode: true)
    @on 'application:minimize', -> Menu.sendActionToFirstResponder('performMiniaturize:')
    @on 'application:zoom', -> Menu.sendActionToFirstResponder('zoom:')
    @on 'application:bring-all-windows-to-front', -> Menu.sendActionToFirstResponder('arrangeInFront:')
    @on 'application:inspect', ({x,y}) -> @focusedWindow().browserWindow.inspectElement(x, y)

    app.on 'will-quit', =>
      fs.unlinkSync socketPath if fs.existsSync(socketPath) # Clean the socket file when quit normally.

    app.on 'open-file', (event, pathToOpen) =>
      event.preventDefault()
      @openPath({pathToOpen})

    app.on 'open-url', (event, urlToOpen) =>
      event.preventDefault()
      @openUrl({urlToOpen, @devMode})

    autoUpdater.on 'ready-for-update-on-quit', (event, version, quitAndUpdateCallback) =>
      event.preventDefault()
      @updateVersion = version
      @applicationMenu.showDownloadUpdateItem(version, quitAndUpdateCallback)
      atomWindow.sendCommand('window:update-available', version) for atomWindow in @windows

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

  # Private: Returns the {AtomWindow} for the given path.
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
      pathToOpen = "#{path.dirname(pathToOpen)}/#{basename}"
      initialLine -= 1 if initialLine # Convert line numbers to a base of 0

    unless devMode
      existingWindow = @windowForPath(pathToOpen) unless pidToKillWhenClosed or newWindow
    if existingWindow
      openedWindow = existingWindow
      openedWindow.openPath(pathToOpen, initialLine)
    else
      if devMode
        resourcePath = global.devResourcePath
        bootstrapScript = require.resolve(path.join(global.devResourcePath, 'src', 'window-bootstrap'))
      else
        resourcePath = @resourcePath
        bootstrapScript = require.resolve('../window-bootstrap')
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

  # Private: Open an atom:// url.
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
      fsUtils = require '../fs-utils'
      @packages = new PackageManager
        configDirPath: fsUtils.absolute('~/.atom')
        devMode: devMode
        resourcePath: @resourcePath

    packageName = url.parse(urlToOpen).host
    pack = _.find @packages.getAvailablePackageMetadata(), ({name}) -> name is packageName
    if pack?
      if pack.urlMain
        packagePath = @packages.resolvePackagePath(packageName)
        bootstrapScript = path.resolve(packagePath, pack.urlMain)
        new AtomWindow({bootstrapScript, @resourcePath, devMode, urlToOpen, initialSize: getFocusedWindowSize()})
      else
        console.log "Package '#{pack.name}' does not have a url main: #{urlToOpen}"
    else
      console.log "Opening unknown url: #{urlToOpen}"

  # Private: Opens up a new {AtomWindow} to run specs within.
  #
  # * options
  #    + exitWhenDone:
  #      A Boolean that if true, will close the window upon completion.
  #    + resourcePath:
  #      The path to include specs from.
  #    + specPath:
  #      The directory to load specs from.
  runSpecs: ({exitWhenDone, resourcePath, specDirectory}) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    try
      bootstrapScript = require.resolve(path.resolve(global.devResourcePath, 'spec', 'spec-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'spec', 'spec-bootstrap'))

    isSpec = true
    devMode = true
    new AtomWindow({bootstrapScript, resourcePath, exitWhenDone, isSpec, devMode, specDirectory})

  runBenchmarks: ->
    try
      bootstrapScript = require.resolve(path.resolve(global.devResourcePath, 'benchmark', 'benchmark-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'benchmark', 'benchmark-bootstrap'))

    isSpec = true # Needed because this flag adds the spec directory to the NODE_PATH
    new AtomWindow({bootstrapScript, @resourcePath, isSpec})

  # Private: Opens a native dialog to prompt the user for a path.
  #
  # Once paths are selected, they're opened in a new or existing {AtomWindow}s.
  #
  # * options
  #    + devMode:
  #      A Boolean which controls whether any newly opened windows should  be in
  #      dev mode or not.
  promptForPath: ({devMode}={}) ->
    pathsToOpen = dialog.showOpenDialog title: 'Open', properties: ['openFile', 'openDirectory', 'multiSelections', 'createDirectory']
    @openPaths({pathsToOpen, devMode})

  # Public: If an update is available, it returns the new version string
  # otherwise it returns null.
  getUpdateVersion: ->
    @updateVersion
