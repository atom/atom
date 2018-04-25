const AtomWindow = require('./atom-window')
const ApplicationMenu = require('./application-menu')
const AtomProtocolHandler = require('./atom-protocol-handler')
const AutoUpdateManager = require('./auto-update-manager')
const StorageFolder = require('../storage-folder')
const Config = require('../config')
const ConfigFile = require('../config-file')
const FileRecoveryService = require('./file-recovery-service')
const ipcHelpers = require('../ipc-helpers')
const {BrowserWindow, Menu, app, dialog, ipcMain, shell, screen} = require('electron')
const {CompositeDisposable, Disposable} = require('event-kit')
const crypto = require('crypto')
const fs = require('fs-plus')
const path = require('path')
const os = require('os')
const net = require('net')
const url = require('url')
const {EventEmitter} = require('events')
const _ = require('underscore-plus')
let FindParentDir = null
let Resolve = null
const ConfigSchema = require('../config-schema')

const LocationSuffixRegExp = /(:\d+)(:\d+)?$/

// The application's singleton class.
//
// It's the entry point into the Atom application and maintains the global state
// of the application.
//
module.exports =
class AtomApplication extends EventEmitter {
  // Public: The entry point into the Atom application.
  static open (options) {
    if (!options.socketPath) {
      const {username} = os.userInfo()

      // Lowercasing the ATOM_HOME to make sure that we don't get multiple sockets
      // on case-insensitive filesystems due to arbitrary case differences in paths.
      const atomHomeUnique = path.resolve(process.env.ATOM_HOME).toLowerCase()
      const hash = crypto
        .createHash('sha1')
        .update(options.version)
        .update('|')
        .update(process.arch)
        .update('|')
        .update(username || '')
        .update('|')
        .update(atomHomeUnique)

      // We only keep the first 12 characters of the hash as not to have excessively long
      // socket file. Note that macOS/BSD limit the length of socket file paths (see #15081).
      // The replace calls convert the digest into "URL and Filename Safe" encoding (see RFC 4648).
      const atomInstanceDigest = hash
        .digest('base64')
        .substring(0, 12)
        .replace(/\+/g, '-')
        .replace(/\//g, '_')

      if (process.platform === 'win32') {
        options.socketPath = `\\\\.\\pipe\\atom-${atomInstanceDigest}-sock`
      } else {
        options.socketPath = path.join(os.tmpdir(), `atom-${atomInstanceDigest}.sock`)
      }
    }

    // FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    // take a few seconds to trigger 'error' event, it could be a bug of node
    // or electron, before it's fixed we check the existence of socketPath to
    // speedup startup.
    if ((process.platform !== 'win32' && !fs.existsSync(options.socketPath)) ||
        options.test || options.benchmark || options.benchmarkTest) {
      new AtomApplication(options).initialize(options)
      return
    }

    const client = net.connect({path: options.socketPath}, () => {
      client.write(JSON.stringify(options), () => {
        client.end()
        app.quit()
      })
    })

    client.on('error', () => new AtomApplication(options).initialize(options))
  }

  exit (status) {
    app.exit(status)
  }

  constructor (options) {
    super()
    this.quitting = false
    this.getAllWindows = this.getAllWindows.bind(this)
    this.getLastFocusedWindow = this.getLastFocusedWindow.bind(this)
    this.resourcePath = options.resourcePath
    this.devResourcePath = options.devResourcePath
    this.version = options.version
    this.devMode = options.devMode
    this.safeMode = options.safeMode
    this.socketPath = options.socketPath
    this.logFile = options.logFile
    this.userDataDir = options.userDataDir
    this._killProcess = options.killProcess || process.kill.bind(process)
    if (options.test || options.benchmark || options.benchmarkTest) this.socketPath = null

    this.waitSessionsByWindow = new Map()
    this.windowStack = new WindowStack()

    this.initializeAtomHome(process.env.ATOM_HOME)

    const configFilePath = fs.existsSync(path.join(process.env.ATOM_HOME, 'config.json'))
      ? path.join(process.env.ATOM_HOME, 'config.json')
      : path.join(process.env.ATOM_HOME, 'config.cson')

    this.configFile = ConfigFile.at(configFilePath)
    this.config = new Config({
      saveCallback: settings => {
        if (!this.quitting) {
          return this.configFile.update(settings)
        }
      }
    })
    this.config.setSchema(null, {type: 'object', properties: _.clone(ConfigSchema)})

    this.fileRecoveryService = new FileRecoveryService(path.join(process.env.ATOM_HOME, 'recovery'))
    this.storageFolder = new StorageFolder(process.env.ATOM_HOME)
    this.autoUpdateManager = new AutoUpdateManager(
      this.version,
      options.test || options.benchmark || options.benchmarkTest,
      this.config
    )

    this.disposable = new CompositeDisposable()
    this.handleEvents()
  }

  // This stuff was previously done in the constructor, but we want to be able to construct this object
  // for testing purposes without booting up the world. As you add tests, feel free to move instantiation
  // of these various sub-objects into the constructor, but you'll need to remove the side-effects they
  // perform during their construction, adding an initialize method that you call here.
  initialize (options) {
    global.atomApplication = this

    // DEPRECATED: This can be removed at some point (added in 1.13)
    // It converts `useCustomTitleBar: true` to `titleBar: "custom"`
    if (process.platform === 'darwin' && this.config.get('core.useCustomTitleBar')) {
      this.config.unset('core.useCustomTitleBar')
      this.config.set('core.titleBar', 'custom')
    }

    process.nextTick(() => this.autoUpdateManager.initialize())
    this.applicationMenu = new ApplicationMenu(this.version, this.autoUpdateManager)
    this.atomProtocolHandler = new AtomProtocolHandler(this.resourcePath, this.safeMode)

    this.listenForArgumentsFromNewProcess()
    this.setupDockMenu()

    return this.launch(options)
  }

  async destroy () {
    const windowsClosePromises = this.getAllWindows().map(window => {
      window.close()
      return window.closedPromise
    })
    await Promise.all(windowsClosePromises)
    this.disposable.dispose()
  }

  async launch (options) {
    if (!this.configFilePromise) {
      this.configFilePromise = this.configFile.watch()
      this.disposable.add(await this.configFilePromise)
      this.config.onDidChange('core.titleBar', this.promptForRestart.bind(this))
    }

    const optionsForWindowsToOpen = []

    let shouldReopenPreviousWindows = false

    if (options.test || options.benchmark || options.benchmarkTest) {
      optionsForWindowsToOpen.push(options)
    } else if ((options.pathsToOpen && options.pathsToOpen.length > 0) ||
               (options.urlsToOpen && options.urlsToOpen.length > 0)) {
      optionsForWindowsToOpen.push(options)
      shouldReopenPreviousWindows = this.config.get('core.restorePreviousWindowsOnStart') === 'always'
    } else {
      shouldReopenPreviousWindows = this.config.get('core.restorePreviousWindowsOnStart') !== 'no'
    }

    if (shouldReopenPreviousWindows) {
      for (const previousOptions of await this.loadPreviousWindowOptions()) {
        optionsForWindowsToOpen.push(Object.assign({}, options, previousOptions))
      }
    }

    if (optionsForWindowsToOpen.length === 0) {
      optionsForWindowsToOpen.push(options)
    }

    return optionsForWindowsToOpen.map(options => this.openWithOptions(options))
  }

  openWithOptions (options) {
    const {
      initialPaths,
      pathsToOpen,
      executedFrom,
      urlsToOpen,
      benchmark,
      benchmarkTest,
      test,
      pidToKillWhenClosed,
      devMode,
      safeMode,
      newWindow,
      logFile,
      profileStartup,
      timeout,
      clearWindowState,
      addToLastWindow,
      env
    } = options

    app.focus()

    if (test) {
      return this.runTests({
        headless: true,
        devMode,
        resourcePath: this.resourcePath,
        executedFrom,
        pathsToOpen,
        logFile,
        timeout,
        env
      })
    } else if (benchmark || benchmarkTest) {
      return this.runBenchmarks({
        headless: true,
        test: benchmarkTest,
        resourcePath: this.resourcePath,
        executedFrom,
        pathsToOpen,
        timeout,
        env
      })
    } else if (pathsToOpen.length > 0) {
      return this.openPaths({
        initialPaths,
        pathsToOpen,
        executedFrom,
        pidToKillWhenClosed,
        newWindow,
        devMode,
        safeMode,
        profileStartup,
        clearWindowState,
        addToLastWindow,
        env
      })
    } else if (urlsToOpen.length > 0) {
      return urlsToOpen.map(urlToOpen => this.openUrl({urlToOpen, devMode, safeMode, env}))
    } else {
      // Always open a editor window if this is the first instance of Atom.
      return this.openPath({
        initialPaths,
        pidToKillWhenClosed,
        newWindow,
        devMode,
        safeMode,
        profileStartup,
        clearWindowState,
        addToLastWindow,
        env
      })
    }
  }

  // Public: Removes the {AtomWindow} from the global window list.
  removeWindow (window) {
    this.windowStack.removeWindow(window)
    if (this.getAllWindows().length === 0) {
      if (this.applicationMenu != null) {
        this.applicationMenu.enableWindowSpecificItems(false)
      }
      if (['win32', 'linux'].includes(process.platform)) {
        app.quit()
        return
      }
    }
    if (!window.isSpec) this.saveCurrentWindowOptions(true)
  }

  // Public: Adds the {AtomWindow} to the global window list.
  addWindow (window) {
    this.windowStack.addWindow(window)
    if (this.applicationMenu) this.applicationMenu.addWindow(window.browserWindow)

    window.once('window:loaded', () => {
      this.autoUpdateManager && this.autoUpdateManager.emitUpdateAvailableEvent(window)
    })

    if (!window.isSpec) {
      const focusHandler = () => this.windowStack.touch(window)
      const blurHandler = () => this.saveCurrentWindowOptions(false)
      window.browserWindow.on('focus', focusHandler)
      window.browserWindow.on('blur', blurHandler)
      window.browserWindow.once('closed', () => {
        this.windowStack.removeWindow(window)
        window.browserWindow.removeListener('focus', focusHandler)
        window.browserWindow.removeListener('blur', blurHandler)
      })
      window.browserWindow.webContents.once('did-finish-load', blurHandler)
    }
  }

  getAllWindows () {
    return this.windowStack.all().slice()
  }

  getLastFocusedWindow (predicate) {
    return this.windowStack.getLastFocusedWindow(predicate)
  }

  // Creates server to listen for additional atom application launches.
  //
  // You can run the atom command multiple times, but after the first launch
  // the other launches will just pass their information to this server and then
  // close immediately.
  listenForArgumentsFromNewProcess () {
    if (!this.socketPath) return

    this.deleteSocketFile()
    const server = net.createServer(connection => {
      let data = ''
      connection.on('data', chunk => { data += chunk })
      connection.on('end', () => this.openWithOptions(JSON.parse(data)))
    })

    server.listen(this.socketPath)
    server.on('error', error => console.error('Application server failed', error))
  }

  deleteSocketFile () {
    if (process.platform === 'win32' || !this.socketPath) return

    if (fs.existsSync(this.socketPath)) {
      try {
        fs.unlinkSync(this.socketPath)
      } catch (error) {
        // Ignore ENOENT errors in case the file was deleted between the exists
        // check and the call to unlink sync. This occurred occasionally on CI
        // which is why this check is here.
        if (error.code !== 'ENOENT') throw error
      }
    }
  }

  // Registers basic application commands, non-idempotent.
  handleEvents () {
    const getLoadSettings = () => {
      const window = this.focusedWindow()
      return {devMode: window && window.devMode, safeMode: window && window.safeMode}
    }

    this.on('application:quit', () => app.quit())
    this.on('application:new-window', () => this.openPath(getLoadSettings()))
    this.on('application:new-file', () => (this.focusedWindow() || this).openPath())
    this.on('application:open-dev', () => this.promptForPathToOpen('all', {devMode: true}))
    this.on('application:open-safe', () => this.promptForPathToOpen('all', {safeMode: true}))
    this.on('application:inspect', ({x, y, atomWindow}) => {
      if (!atomWindow) atomWindow = this.focusedWindow()
      if (atomWindow) atomWindow.browserWindow.inspectElement(x, y)
    })

    this.on('application:open-documentation', () => shell.openExternal('http://flight-manual.atom.io'))
    this.on('application:open-discussions', () => shell.openExternal('https://discuss.atom.io'))
    this.on('application:open-faq', () => shell.openExternal('https://atom.io/faq'))
    this.on('application:open-terms-of-use', () => shell.openExternal('https://atom.io/terms'))
    this.on('application:report-issue', () => shell.openExternal('https://github.com/atom/atom/blob/master/CONTRIBUTING.md#reporting-bugs'))
    this.on('application:search-issues', () => shell.openExternal('https://github.com/search?q=+is%3Aissue+user%3Aatom'))

    this.on('application:install-update', () => {
      this.quitting = true
      this.autoUpdateManager.install()
    })

    this.on('application:check-for-update', () => this.autoUpdateManager.check())

    if (process.platform === 'darwin') {
      this.on('application:bring-all-windows-to-front', () => Menu.sendActionToFirstResponder('arrangeInFront:'))
      this.on('application:hide', () => Menu.sendActionToFirstResponder('hide:'))
      this.on('application:hide-other-applications', () => Menu.sendActionToFirstResponder('hideOtherApplications:'))
      this.on('application:minimize', () => Menu.sendActionToFirstResponder('performMiniaturize:'))
      this.on('application:unhide-all-applications', () => Menu.sendActionToFirstResponder('unhideAllApplications:'))
      this.on('application:zoom', () => Menu.sendActionToFirstResponder('zoom:'))
    } else {
      this.on('application:minimize', () => {
        const window = this.focusedWindow()
        if (window) window.minimize()
      })
      this.on('application:zoom', function () {
        const window = this.focusedWindow()
        if (window) window.maximize()
      })
    }

    this.openPathOnEvent('application:about', 'atom://about')
    this.openPathOnEvent('application:show-settings', 'atom://config')
    this.openPathOnEvent('application:open-your-config', 'atom://.atom/config')
    this.openPathOnEvent('application:open-your-init-script', 'atom://.atom/init-script')
    this.openPathOnEvent('application:open-your-keymap', 'atom://.atom/keymap')
    this.openPathOnEvent('application:open-your-snippets', 'atom://.atom/snippets')
    this.openPathOnEvent('application:open-your-stylesheet', 'atom://.atom/stylesheet')
    this.openPathOnEvent('application:open-license', path.join(process.resourcesPath, 'LICENSE.md'))

    this.configFile.onDidChange(settings => {
      for (let window of this.getAllWindows()) {
        window.didChangeUserSettings(settings)
      }
      this.config.resetUserSettings(settings)
    })

    this.configFile.onDidError(message => {
      const window = this.focusedWindow() || this.getLastFocusedWindow()
      if (window) window.didFailToReadUserSettings(message)
    })

    this.disposable.add(ipcHelpers.on(app, 'before-quit', async event => {
      let resolveBeforeQuitPromise
      this.lastBeforeQuitPromise = new Promise(resolve => { resolveBeforeQuitPromise = resolve })

      if (!this.quitting) {
        this.quitting = true
        event.preventDefault()
        const windowUnloadPromises = this.getAllWindows().map(window => window.prepareToUnload())
        const windowUnloadedResults = await Promise.all(windowUnloadPromises)
        if (windowUnloadedResults.every(Boolean)) {
          app.quit()
        } else {
          this.quitting = false
        }
      }

      resolveBeforeQuitPromise()
    }))

    this.disposable.add(ipcHelpers.on(app, 'will-quit', () => {
      this.killAllProcesses()
      this.deleteSocketFile()
    }))

    this.disposable.add(ipcHelpers.on(app, 'open-file', (event, pathToOpen) => {
      event.preventDefault()
      this.openPath({pathToOpen})
    }))

    this.disposable.add(ipcHelpers.on(app, 'open-url', (event, urlToOpen) => {
      event.preventDefault()
      this.openUrl({urlToOpen, devMode: this.devMode, safeMode: this.safeMode})
    }))

    this.disposable.add(ipcHelpers.on(app, 'activate', (event, hasVisibleWindows) => {
      if (hasVisibleWindows) return
      if (event) event.preventDefault()
      this.emit('application:new-window')
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'restart-application', () => {
      this.restart()
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'resolve-proxy', (event, requestId, url) => {
      event.sender.session.resolveProxy(url, proxy => {
        if (!event.sender.isDestroyed()) event.sender.send('did-resolve-proxy', requestId, proxy)
      })
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'did-change-history-manager', event => {
      for (let atomWindow of this.getAllWindows()) {
        const {webContents} = atomWindow.browserWindow
        if (webContents !== event.sender) webContents.send('did-change-history-manager')
      }
    }))

    // A request from the associated render process to open a new render process.
    this.disposable.add(ipcHelpers.on(ipcMain, 'open', (event, options) => {
      const window = this.atomWindowForEvent(event)
      if (options) {
        if (typeof options.pathsToOpen === 'string') {
          options.pathsToOpen = [options.pathsToOpen]
        }

        if (options.pathsToOpen && options.pathsToOpen.length > 0) {
          options.window = window
          this.openPaths(options)
        } else {
          this.addWindow(new AtomWindow(this, this.fileRecoveryService, options))
        }
      } else {
        this.promptForPathToOpen('all', {window})
      }
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'update-application-menu', (event, template, menu) => {
      const window = BrowserWindow.fromWebContents(event.sender)
      if (this.applicationMenu) this.applicationMenu.update(window, template, menu)
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'run-package-specs', (event, packageSpecPath) => {
      this.runTests({
        resourcePath: this.devResourcePath,
        pathsToOpen: [packageSpecPath],
        headless: false
      })
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'run-benchmarks', (event, benchmarksPath) => {
      this.runBenchmarks({
        resourcePath: this.devResourcePath,
        pathsToOpen: [benchmarksPath],
        headless: false,
        test: false
      })
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'command', (event, command) => {
      this.emit(command)
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'open-command', (event, command, defaultPath) => {
      switch (command) {
        case 'application:open':
          return this.promptForPathToOpen('all', getLoadSettings(), defaultPath)
        case 'application:open-file':
          return this.promptForPathToOpen('file', getLoadSettings(), defaultPath)
        case 'application:open-folder':
          return this.promptForPathToOpen('folder', getLoadSettings(), defaultPath)
        default:
          return console.log(`Invalid open-command received: ${command}`)
      }
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'window-command', (event, command, ...args) => {
      const window = BrowserWindow.fromWebContents(event.sender)
      return window.emit(command, ...args)
    }))

    this.disposable.add(ipcHelpers.respondTo('window-method', (browserWindow, method, ...args) => {
      const window = this.atomWindowForBrowserWindow(browserWindow)
      if (window) window[method](...args)
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'pick-folder', (event, responseChannel) => {
      this.promptForPath('folder', paths => event.sender.send(responseChannel, paths))
    }))

    this.disposable.add(ipcHelpers.respondTo('set-window-size', (window, width, height) => {
      window.setSize(width, height)
    }))

    this.disposable.add(ipcHelpers.respondTo('set-window-position', (window, x, y) => {
      window.setPosition(x, y)
    }))

    this.disposable.add(ipcHelpers.respondTo('set-user-settings', (window, settings, filePath) => {
      if (!this.quitting) {
        ConfigFile.at(filePath || this.configFilePath).update(JSON.parse(settings))
      }
    }))

    this.disposable.add(ipcHelpers.respondTo('center-window', window => window.center()))
    this.disposable.add(ipcHelpers.respondTo('focus-window', window => window.focus()))
    this.disposable.add(ipcHelpers.respondTo('show-window', window => window.show()))
    this.disposable.add(ipcHelpers.respondTo('hide-window', window => window.hide()))
    this.disposable.add(ipcHelpers.respondTo('get-temporary-window-state', window => window.temporaryState))

    this.disposable.add(ipcHelpers.respondTo('set-temporary-window-state', (win, state) => {
      win.temporaryState = state
    }))

    const clipboard = require('../safe-clipboard')
    this.disposable.add(ipcHelpers.on(ipcMain, 'write-text-to-selection-clipboard', (event, text) =>
      clipboard.writeText(text, 'selection')
    ))

    this.disposable.add(ipcHelpers.on(ipcMain, 'write-to-stdout', (event, output) =>
      process.stdout.write(output)
    ))

    this.disposable.add(ipcHelpers.on(ipcMain, 'write-to-stderr', (event, output) =>
      process.stderr.write(output)
    ))

    this.disposable.add(ipcHelpers.on(ipcMain, 'add-recent-document', (event, filename) =>
      app.addRecentDocument(filename)
    ))

    this.disposable.add(ipcHelpers.on(ipcMain, 'execute-javascript-in-dev-tools', (event, code) =>
      event.sender.devToolsWebContents && event.sender.devToolsWebContents.executeJavaScript(code)
    ))

    this.disposable.add(ipcHelpers.on(ipcMain, 'get-auto-update-manager-state', event => {
      event.returnValue = this.autoUpdateManager.getState()
    }))

    this.disposable.add(ipcHelpers.on(ipcMain, 'get-auto-update-manager-error', event => {
      event.returnValue = this.autoUpdateManager.getErrorMessage()
    }))

    this.disposable.add(ipcHelpers.respondTo('will-save-path', (window, path) =>
      this.fileRecoveryService.willSavePath(window, path)
    ))

    this.disposable.add(ipcHelpers.respondTo('did-save-path', (window, path) =>
      this.fileRecoveryService.didSavePath(window, path)
    ))

    this.disposable.add(ipcHelpers.on(ipcMain, 'did-change-paths', () =>
      this.saveCurrentWindowOptions(false)
    ))

    this.disposable.add(this.disableZoomOnDisplayChange())
  }

  setupDockMenu () {
    if (process.platform === 'darwin') {
      return app.dock.setMenu(Menu.buildFromTemplate([
        {label: 'New Window', click: () => this.emit('application:new-window')}
      ]))
    }
  }

  initializeAtomHome (configDirPath) {
    if (!fs.existsSync(configDirPath)) {
      const templateConfigDirPath = fs.resolve(this.resourcePath, 'dot-atom')
      fs.copySync(templateConfigDirPath, configDirPath)
    }
  }

  // Public: Executes the given command.
  //
  // If it isn't handled globally, delegate to the currently focused window.
  //
  // command - The string representing the command.
  // args - The optional arguments to pass along.
  sendCommand (command, ...args) {
    if (!this.emit(command, ...args)) {
      const focusedWindow = this.focusedWindow()
      if (focusedWindow) {
        return focusedWindow.sendCommand(command, ...args)
      } else {
        return this.sendCommandToFirstResponder(command)
      }
    }
  }

  // Public: Executes the given command on the given window.
  //
  // command - The string representing the command.
  // atomWindow - The {AtomWindow} to send the command to.
  // args - The optional arguments to pass along.
  sendCommandToWindow (command, atomWindow, ...args) {
    if (!this.emit(command, ...args)) {
      if (atomWindow) {
        return atomWindow.sendCommand(command, ...args)
      } else {
        return this.sendCommandToFirstResponder(command)
      }
    }
  }

  // Translates the command into macOS action and sends it to application's first
  // responder.
  sendCommandToFirstResponder (command) {
    if (process.platform !== 'darwin') return false

    switch (command) {
      case 'core:undo':
        Menu.sendActionToFirstResponder('undo:')
        break
      case 'core:redo':
        Menu.sendActionToFirstResponder('redo:')
        break
      case 'core:copy':
        Menu.sendActionToFirstResponder('copy:')
        break
      case 'core:cut':
        Menu.sendActionToFirstResponder('cut:')
        break
      case 'core:paste':
        Menu.sendActionToFirstResponder('paste:')
        break
      case 'core:select-all':
        Menu.sendActionToFirstResponder('selectAll:')
        break
      default:
        return false
    }
    return true
  }

  // Public: Open the given path in the focused window when the event is
  // triggered.
  //
  // A new window will be created if there is no currently focused window.
  //
  // eventName - The event to listen for.
  // pathToOpen - The path to open when the event is triggered.
  openPathOnEvent (eventName, pathToOpen) {
    this.on(eventName, () => {
      const window = this.focusedWindow()
      if (window) {
        return window.openPath(pathToOpen)
      } else {
        return this.openPath({pathToOpen})
      }
    })
  }

  // Returns the {AtomWindow} for the given paths.
  windowForPaths (pathsToOpen, devMode) {
    return this.getAllWindows().find(window =>
      window.devMode === devMode && window.containsPaths(pathsToOpen)
    )
  }

  // Returns the {AtomWindow} for the given ipcMain event.
  atomWindowForEvent ({sender}) {
    return this.atomWindowForBrowserWindow(BrowserWindow.fromWebContents(sender))
  }

  atomWindowForBrowserWindow (browserWindow) {
    return this.getAllWindows().find(atomWindow => atomWindow.browserWindow === browserWindow)
  }

  // Public: Returns the currently focused {AtomWindow} or undefined if none.
  focusedWindow () {
    return this.getAllWindows().find(window => window.isFocused())
  }

  // Get the platform-specific window offset for new windows.
  getWindowOffsetForCurrentPlatform () {
    const offsetByPlatform = {
      darwin: 22,
      win32: 26
    }
    return offsetByPlatform[process.platform] || 0
  }

  // Get the dimensions for opening a new window by cascading as appropriate to
  // the platform.
  getDimensionsForNewWindow () {
    const window = this.focusedWindow() || this.getLastFocusedWindow()
    if (!window || window.isMaximized()) return
    const dimensions = window.getDimensions()
    if (dimensions) {
      const offset = this.getWindowOffsetForCurrentPlatform()
      dimensions.x += offset
      dimensions.y += offset
      return dimensions
    }
  }

  // Public: Opens a single path, in an existing window if possible.
  //
  // options -
  //   :pathToOpen - The file path to open
  //   :pidToKillWhenClosed - The integer of the pid to kill
  //   :newWindow - Boolean of whether this should be opened in a new window.
  //   :devMode - Boolean to control the opened window's dev mode.
  //   :safeMode - Boolean to control the opened window's safe mode.
  //   :profileStartup - Boolean to control creating a profile of the startup time.
  //   :window - {AtomWindow} to open file paths in.
  //   :addToLastWindow - Boolean of whether this should be opened in last focused window.
  openPath ({
    initialPaths,
    pathToOpen,
    pidToKillWhenClosed,
    newWindow,
    devMode,
    safeMode,
    profileStartup,
    window,
    clearWindowState,
    addToLastWindow,
    env
  } = {}) {
    return this.openPaths({
      initialPaths,
      pathsToOpen: [pathToOpen],
      pidToKillWhenClosed,
      newWindow,
      devMode,
      safeMode,
      profileStartup,
      window,
      clearWindowState,
      addToLastWindow,
      env
    })
  }

  // Public: Opens multiple paths, in existing windows if possible.
  //
  // options -
  //   :pathsToOpen - The array of file paths to open
  //   :pidToKillWhenClosed - The integer of the pid to kill
  //   :newWindow - Boolean of whether this should be opened in a new window.
  //   :devMode - Boolean to control the opened window's dev mode.
  //   :safeMode - Boolean to control the opened window's safe mode.
  //   :windowDimensions - Object with height and width keys.
  //   :window - {AtomWindow} to open file paths in.
  //   :addToLastWindow - Boolean of whether this should be opened in last focused window.
  openPaths ({
    initialPaths,
    pathsToOpen,
    executedFrom,
    pidToKillWhenClosed,
    newWindow,
    devMode,
    safeMode,
    windowDimensions,
    profileStartup,
    window,
    clearWindowState,
    addToLastWindow,
    env
  } = {}) {
    if (!pathsToOpen || pathsToOpen.length === 0) return
    if (!env) env = process.env
    devMode = Boolean(devMode)
    safeMode = Boolean(safeMode)
    clearWindowState = Boolean(clearWindowState)

    const locationsToOpen = []
    for (let i = 0; i < pathsToOpen.length; i++) {
      const location = this.parsePathToOpen(pathsToOpen[i], executedFrom, addToLastWindow)
      location.forceAddToWindow = addToLastWindow
      location.hasWaitSession = pidToKillWhenClosed != null
      locationsToOpen.push(location)
      pathsToOpen[i] = location.pathToOpen
    }

    let existingWindow
    if (!newWindow) {
      existingWindow = this.windowForPaths(pathsToOpen, devMode)
      if (!existingWindow) {
        let lastWindow = window || this.getLastFocusedWindow()
        if (lastWindow && lastWindow.devMode === devMode) {
          if (addToLastWindow || (
              locationsToOpen.every(({stat}) => stat && stat.isFile()) ||
              (locationsToOpen.some(({stat}) => stat && stat.isDirectory()) && !lastWindow.hasProjectPath()))) {
            existingWindow = lastWindow
          }
        }
      }
    }

    let openedWindow
    if (existingWindow) {
      openedWindow = existingWindow
      openedWindow.openLocations(locationsToOpen)
      if (openedWindow.isMinimized()) {
        openedWindow.restore()
      } else {
        openedWindow.focus()
      }
      openedWindow.replaceEnvironment(env)
    } else {
      let resourcePath, windowInitializationScript
      if (devMode) {
        try {
          windowInitializationScript = require.resolve(
            path.join(this.devResourcePath, 'src', 'initialize-application-window')
          )
          resourcePath = this.devResourcePath
        } catch (error) {}
      }

      if (!windowInitializationScript) {
        windowInitializationScript = require.resolve('../initialize-application-window')
      }
      if (!resourcePath) resourcePath = this.resourcePath
      if (!windowDimensions) windowDimensions = this.getDimensionsForNewWindow()

      openedWindow = new AtomWindow(this, this.fileRecoveryService, {
        initialPaths,
        locationsToOpen,
        windowInitializationScript,
        resourcePath,
        devMode,
        safeMode,
        windowDimensions,
        profileStartup,
        clearWindowState,
        env
      })
      this.addWindow(openedWindow)
      openedWindow.focus()
    }

    if (pidToKillWhenClosed != null) {
      if (!this.waitSessionsByWindow.has(openedWindow)) {
        this.waitSessionsByWindow.set(openedWindow, [])
      }
      this.waitSessionsByWindow.get(openedWindow).push({
        pid: pidToKillWhenClosed,
        remainingPaths: new Set(pathsToOpen)
      })
    }

    openedWindow.browserWindow.once('closed', () => this.killProcessesForWindow(openedWindow))
    return openedWindow
  }

  // Kill all processes associated with opened windows.
  killAllProcesses () {
    for (let window of this.waitSessionsByWindow.keys()) {
      this.killProcessesForWindow(window)
    }
  }

  killProcessesForWindow (window) {
    const sessions = this.waitSessionsByWindow.get(window)
    if (!sessions) return
    for (const session of sessions) {
      this.killProcess(session.pid)
    }
    this.waitSessionsByWindow.delete(window)
  }

  windowDidClosePathWithWaitSession (window, initialPath) {
    const waitSessions = this.waitSessionsByWindow.get(window)
    if (!waitSessions) return
    for (let i = waitSessions.length - 1; i >= 0; i--) {
      const session = waitSessions[i]
      session.remainingPaths.delete(initialPath)
      if (session.remainingPaths.size === 0) {
        this.killProcess(session.pid)
        waitSessions.splice(i, 1)
      }
    }
  }

  // Kill the process with the given pid.
  killProcess (pid) {
    try {
      const parsedPid = parseInt(pid)
      if (isFinite(parsedPid)) this._killProcess(parsedPid)
    } catch (error) {
      if (error.code !== 'ESRCH') {
        console.log(`Killing process ${pid} failed: ${error.code != null ? error.code : error.message}`)
      }
    }
  }

  async saveCurrentWindowOptions (allowEmpty = false) {
    if (this.quitting) return

    const states = []
    for (let window of this.getAllWindows()) {
      if (!window.isSpec) states.push({initialPaths: window.representedDirectoryPaths})
    }
    states.reverse()

    if (states.length > 0 || allowEmpty) {
      await this.storageFolder.store('application.json', states)
      this.emit('application:did-save-state')
    }
  }

  async loadPreviousWindowOptions () {
    const states = await this.storageFolder.load('application.json')
    if (states) {
      return states.map(state => ({
        initialPaths: state.initialPaths,
        pathsToOpen: state.initialPaths.filter(p => fs.isDirectorySync(p)),
        urlsToOpen: [],
        devMode: this.devMode,
        safeMode: this.safeMode
      }))
    } else {
      return []
    }
  }

  // Open an atom:// url.
  //
  // The host of the URL being opened is assumed to be the package name
  // responsible for opening the URL.  A new window will be created with
  // that package's `urlMain` as the bootstrap script.
  //
  // options -
  //   :urlToOpen - The atom:// url to open.
  //   :devMode - Boolean to control the opened window's dev mode.
  //   :safeMode - Boolean to control the opened window's safe mode.
  openUrl ({urlToOpen, devMode, safeMode, env}) {
    const parsedUrl = url.parse(urlToOpen, true)
    if (parsedUrl.protocol !== 'atom:') return

    const pack = this.findPackageWithName(parsedUrl.host, devMode)
    if (pack && pack.urlMain) {
      return this.openPackageUrlMain(
        parsedUrl.host,
        pack.urlMain,
        urlToOpen,
        devMode,
        safeMode,
        env
      )
    } else {
      return this.openPackageUriHandler(urlToOpen, parsedUrl, devMode, safeMode, env)
    }
  }

  openPackageUriHandler (url, parsedUrl, devMode, safeMode, env) {
    let bestWindow

    if (parsedUrl.host === 'core') {
      const predicate = require('../core-uri-handlers').windowPredicate(parsedUrl)
      bestWindow = this.getLastFocusedWindow(win => !win.isSpecWindow() && predicate(win))
    }

    if (!bestWindow) bestWindow = this.getLastFocusedWindow(win => !win.isSpecWindow())

    if (bestWindow) {
      bestWindow.sendURIMessage(url)
      bestWindow.focus()
    } else {
      let windowInitializationScript
      let {resourcePath} = this
      if (devMode) {
        try {
          windowInitializationScript = require.resolve(
            path.join(this.devResourcePath, 'src', 'initialize-application-window')
          )
          resourcePath = this.devResourcePath
        } catch (error) {}
      }

      if (!windowInitializationScript) {
        windowInitializationScript = require.resolve('../initialize-application-window')
      }

      const windowDimensions = this.getDimensionsForNewWindow()
      const window = new AtomWindow(this, this.fileRecoveryService, {
        resourcePath,
        windowInitializationScript,
        devMode,
        safeMode,
        windowDimensions,
        env
      })
      this.addWindow(window)
      window.on('window:loaded', () => window.sendURIMessage(url))
      return window
    }
  }

  findPackageWithName (packageName, devMode) {
    return this.getPackageManager(devMode).getAvailablePackageMetadata().find(({name}) =>
      name === packageName
    )
  }

  openPackageUrlMain (packageName, packageUrlMain, urlToOpen, devMode, safeMode, env) {
    const packagePath = this.getPackageManager(devMode).resolvePackagePath(packageName)
    const windowInitializationScript = path.resolve(packagePath, packageUrlMain)
    const windowDimensions = this.getDimensionsForNewWindow()
    const window = new AtomWindow(this, this.fileRecoveryService, {
      windowInitializationScript,
      resourcePath: this.resourcePath,
      devMode,
      safeMode,
      urlToOpen,
      windowDimensions,
      env
    })
    this.addWindow(window)
    return window
  }

  getPackageManager (devMode) {
    if (this.packages == null) {
      const PackageManager = require('../package-manager')
      this.packages = new PackageManager({})
      this.packages.initialize({
        configDirPath: process.env.ATOM_HOME,
        devMode,
        resourcePath: this.resourcePath
      })
    }

    return this.packages
  }

  // Opens up a new {AtomWindow} to run specs within.
  //
  // options -
  //   :headless - A Boolean that, if true, will close the window upon
  //                   completion.
  //   :resourcePath - The path to include specs from.
  //   :specPath - The directory to load specs from.
  //   :safeMode - A Boolean that, if true, won't run specs from ~/.atom/packages
  //               and ~/.atom/dev/packages, defaults to false.
  runTests ({headless, resourcePath, executedFrom, pathsToOpen, logFile, safeMode, timeout, env}) {
    let windowInitializationScript
    if (resourcePath !== this.resourcePath && !fs.existsSync(resourcePath)) {
      ;({resourcePath} = this)
    }

    const timeoutInSeconds = Number.parseFloat(timeout)
    if (!Number.isNaN(timeoutInSeconds)) {
      const timeoutHandler = function () {
        console.log(
          `The test suite has timed out because it has been running for more than ${timeoutInSeconds} seconds.`
        )
        return process.exit(124) // Use the same exit code as the UNIX timeout util.
      }
      setTimeout(timeoutHandler, timeoutInSeconds * 1000)
    }

    try {
      windowInitializationScript = require.resolve(
        path.resolve(this.devResourcePath, 'src', 'initialize-test-window')
      )
    } catch (error) {
      windowInitializationScript = require.resolve(
        path.resolve(__dirname, '..', '..', 'src', 'initialize-test-window')
      )
    }

    const testPaths = []
    if (pathsToOpen != null) {
      for (let pathToOpen of pathsToOpen) {
        testPaths.push(path.resolve(executedFrom, fs.normalize(pathToOpen)))
      }
    }

    if (testPaths.length === 0) {
      process.stderr.write('Error: Specify at least one test path\n\n')
      process.exit(1)
    }

    const legacyTestRunnerPath = this.resolveLegacyTestRunnerPath()
    const testRunnerPath = this.resolveTestRunnerPath(testPaths[0])
    const devMode = true
    const isSpec = true
    if (safeMode == null) {
      safeMode = false
    }
    const window = new AtomWindow(this, this.fileRecoveryService, {
      windowInitializationScript,
      resourcePath,
      headless,
      isSpec,
      devMode,
      testRunnerPath,
      legacyTestRunnerPath,
      testPaths,
      logFile,
      safeMode,
      env
    })
    this.addWindow(window)
    return window
  }

  runBenchmarks ({headless, test, resourcePath, executedFrom, pathsToOpen, env}) {
    let windowInitializationScript
    if (resourcePath !== this.resourcePath && !fs.existsSync(resourcePath)) {
      ;({resourcePath} = this)
    }

    try {
      windowInitializationScript = require.resolve(
        path.resolve(this.devResourcePath, 'src', 'initialize-benchmark-window')
      )
    } catch (error) {
      windowInitializationScript = require.resolve(
        path.resolve(__dirname, '..', '..', 'src', 'initialize-benchmark-window')
      )
    }

    const benchmarkPaths = []
    if (pathsToOpen != null) {
      for (let pathToOpen of pathsToOpen) {
        benchmarkPaths.push(path.resolve(executedFrom, fs.normalize(pathToOpen)))
      }
    }

    if (benchmarkPaths.length === 0) {
      process.stderr.write('Error: Specify at least one benchmark path.\n\n')
      process.exit(1)
    }

    const devMode = true
    const isSpec = true
    const safeMode = false
    const window = new AtomWindow(this, this.fileRecoveryService, {
      windowInitializationScript,
      resourcePath,
      headless,
      test,
      isSpec,
      devMode,
      benchmarkPaths,
      safeMode,
      env
    })
    this.addWindow(window)
    return window
  }

  resolveTestRunnerPath (testPath) {
    let packageRoot
    if (FindParentDir == null) {
      FindParentDir = require('find-parent-dir')
    }

    if ((packageRoot = FindParentDir.sync(testPath, 'package.json'))) {
      const packageMetadata = require(path.join(packageRoot, 'package.json'))
      if (packageMetadata.atomTestRunner) {
        let testRunnerPath
        if (Resolve == null) {
          Resolve = require('resolve')
        }
        if (
          (testRunnerPath = Resolve.sync(packageMetadata.atomTestRunner, {
            basedir: packageRoot,
            extensions: Object.keys(require.extensions)
          }))
        ) {
          return testRunnerPath
        } else {
          process.stderr.write(
            `Error: Could not resolve test runner path '${packageMetadata.atomTestRunner}'`
          )
          process.exit(1)
        }
      }
    }

    return this.resolveLegacyTestRunnerPath()
  }

  resolveLegacyTestRunnerPath () {
    try {
      return require.resolve(path.resolve(this.devResourcePath, 'spec', 'jasmine-test-runner'))
    } catch (error) {
      return require.resolve(path.resolve(__dirname, '..', '..', 'spec', 'jasmine-test-runner'))
    }
  }

  parsePathToOpen (pathToOpen, executedFrom = '') {
    let initialColumn, initialLine
    if (!pathToOpen) {
      return {pathToOpen}
    }

    pathToOpen = pathToOpen.replace(/[:\s]+$/, '')
    const match = pathToOpen.match(LocationSuffixRegExp)

    if (match != null) {
      pathToOpen = pathToOpen.slice(0, -match[0].length)
      if (match[1]) {
        initialLine = Math.max(0, parseInt(match[1].slice(1)) - 1)
      }
      if (match[2]) {
        initialColumn = Math.max(0, parseInt(match[2].slice(1)) - 1)
      }
    } else {
      initialLine = initialColumn = null
    }

    const normalizedPath = path.normalize(path.resolve(executedFrom, fs.normalize(pathToOpen)))
    const stat = fs.statSyncNoException(normalizedPath)
    if (stat || !url.parse(pathToOpen).protocol) pathToOpen = normalizedPath

    return {pathToOpen, stat, initialLine, initialColumn}
  }

  // Opens a native dialog to prompt the user for a path.
  //
  // Once paths are selected, they're opened in a new or existing {AtomWindow}s.
  //
  // options -
  //   :type - A String which specifies the type of the dialog, could be 'file',
  //           'folder' or 'all'. The 'all' is only available on macOS.
  //   :devMode - A Boolean which controls whether any newly opened windows
  //              should be in dev mode or not.
  //   :safeMode - A Boolean which controls whether any newly opened windows
  //               should be in safe mode or not.
  //   :window - An {AtomWindow} to use for opening a selected file path.
  //   :path - An optional String which controls the default path to which the
  //           file dialog opens.
  promptForPathToOpen (type, {devMode, safeMode, window}, path = null) {
    return this.promptForPath(
      type,
      pathsToOpen => {
        return this.openPaths({pathsToOpen, devMode, safeMode, window})
      },
      path
    )
  }

  promptForPath (type, callback, path) {
    const properties = (() => {
      switch (type) {
        case 'file': return ['openFile']
        case 'folder': return ['openDirectory']
        case 'all': return ['openFile', 'openDirectory']
        default: throw new Error(`${type} is an invalid type for promptForPath`)
      }
    })()

    // Show the open dialog as child window on Windows and Linux, and as
    // independent dialog on macOS. This matches most native apps.
    const parentWindow = process.platform === 'darwin' ? null : BrowserWindow.getFocusedWindow()

    const openOptions = {
      properties: properties.concat(['multiSelections', 'createDirectory']),
      title: (() => {
        switch (type) {
          case 'file': return 'Open File'
          case 'folder': return 'Open Folder'
          default: return 'Open'
        }
      })()
    }

    // File dialog defaults to project directory of currently active editor
    if (path) openOptions.defaultPath = path
    dialog.showOpenDialog(parentWindow, openOptions, callback)
  }

  promptForRestart () {
    dialog.showMessageBox(BrowserWindow.getFocusedWindow(), {
      type: 'warning',
      title: 'Restart required',
      message: 'You will need to restart Atom for this change to take effect.',
      buttons: ['Restart Atom', 'Cancel']
    }, response => { if (response === 0) this.restart() })
  }

  restart () {
    const args = []
    if (this.safeMode) args.push('--safe')
    if (this.logFile != null) args.push(`--log-file=${this.logFile}`)
    if (this.socketPath != null) args.push(`--socket-path=${this.socketPath}`)
    if (this.userDataDir != null) args.push(`--user-data-dir=${this.userDataDir}`)
    if (this.devMode) {
      args.push('--dev')
      args.push(`--resource-path=${this.resourcePath}`)
    }
    app.relaunch({args})
    app.quit()
  }

  disableZoomOnDisplayChange () {
    const callback = () => {
      this.getAllWindows().map(window => window.disableZoom())
    }

    // Set the limits every time a display is added or removed, otherwise the
    // configuration gets reset to the default, which allows zooming the
    // webframe.
    screen.on('display-added', callback)
    screen.on('display-removed', callback)
    return new Disposable(() => {
      screen.removeListener('display-added', callback)
      screen.removeListener('display-removed', callback)
    })
  }
}

class WindowStack {
  constructor (windows = []) {
    this.addWindow = this.addWindow.bind(this)
    this.touch = this.touch.bind(this)
    this.removeWindow = this.removeWindow.bind(this)
    this.getLastFocusedWindow = this.getLastFocusedWindow.bind(this)
    this.all = this.all.bind(this)
    this.windows = windows
  }

  addWindow (window) {
    this.removeWindow(window)
    return this.windows.unshift(window)
  }

  touch (window) {
    return this.addWindow(window)
  }

  removeWindow (window) {
    const currentIndex = this.windows.indexOf(window)
    if (currentIndex > -1) {
      return this.windows.splice(currentIndex, 1)
    }
  }

  getLastFocusedWindow (predicate) {
    if (predicate == null) {
      predicate = win => true
    }
    return this.windows.find(predicate)
  }

  all () {
    return this.windows
  }
}
