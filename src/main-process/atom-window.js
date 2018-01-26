const {BrowserWindow, app, dialog, ipcMain} = require('electron')
const path = require('path')
const fs = require('fs')
const url = require('url')
const {EventEmitter} = require('events')

const ICON_PATH = path.resolve(__dirname, '..', '..', 'resources', 'atom.png')

let includeShellLoadTime = true
let nextId = 0

module.exports =
class AtomWindow extends EventEmitter {
  constructor (atomApplication, fileRecoveryService, settings = {}) {
    super()

    this.id = nextId++
    this.atomApplication = atomApplication
    this.fileRecoveryService = fileRecoveryService
    this.isSpec = settings.isSpec
    this.headless = settings.headless
    this.safeMode = settings.safeMode
    this.devMode = settings.devMode
    this.resourcePath = settings.resourcePath

    let {pathToOpen, locationsToOpen} = settings
    if (!locationsToOpen && pathToOpen) locationsToOpen = [{pathToOpen}]
    if (!locationsToOpen) locationsToOpen = []

    this.loadedPromise = new Promise(resolve => { this.resolveLoadedPromise = resolve })
    this.closedPromise = new Promise(resolve => { this.resolveClosedPromise = resolve })

    const options = {
      show: false,
      title: 'Atom',
      tabbingIdentifier: 'atom',
      webPreferences: {
        // Prevent specs from throttling when the window is in the background:
        // this should result in faster CI builds, and an improvement in the
        // local development experience when running specs through the UI (which
        // now won't pause when e.g. minimizing the window).
        backgroundThrottling: !this.isSpec,
        // Disable the `auxclick` feature so that `click` events are triggered in
        // response to a middle-click.
        // (Ref: https://github.com/atom/atom/pull/12696#issuecomment-290496960)
        disableBlinkFeatures: 'Auxclick'
      }
    }

    // Don't set icon on Windows so the exe's ico will be used as window and
    // taskbar's icon. See https://github.com/atom/atom/issues/4811 for more.
    if (process.platform === 'linux') options.icon = ICON_PATH
    if (this.shouldAddCustomTitleBar()) options.titleBarStyle = 'hidden'
    if (this.shouldAddCustomInsetTitleBar()) options.titleBarStyle = 'hidden-inset'
    if (this.shouldHideTitleBar()) options.frame = false
    this.browserWindow = new BrowserWindow(options)

    Object.defineProperty(this.browserWindow, 'loadSettingsJSON', {
      get: () => JSON.stringify(Object.assign({
        userSettings: this.atomApplication.configFile.get()
      }, this.loadSettings))
    })

    this.handleEvents()

    this.loadSettings = Object.assign({}, settings)
    this.loadSettings.appVersion = app.getVersion()
    this.loadSettings.resourcePath = this.resourcePath
    this.loadSettings.atomHome = process.env.ATOM_HOME
    if (this.loadSettings.devMode == null) this.loadSettings.devMode = false
    if (this.loadSettings.safeMode == null) this.loadSettings.safeMode = false
    if (this.loadSettings.clearWindowState == null) this.loadSettings.clearWindowState = false

    if (!this.loadSettings.initialPaths) {
      this.loadSettings.initialPaths = []
      for (const {pathToOpen} of locationsToOpen) {
        if (!pathToOpen) continue
        const stat = fs.statSyncNoException(pathToOpen) || null
        if (stat && stat.isDirectory()) {
          this.loadSettings.initialPaths.push(pathToOpen)
        } else {
          const parentDirectory = path.dirname(pathToOpen)
          if ((stat && stat.isFile()) || fs.existsSync(parentDirectory)) {
            this.loadSettings.initialPaths.push(parentDirectory)
          } else {
            this.loadSettings.initialPaths.push(pathToOpen)
          }
        }
      }
    }

    this.loadSettings.initialPaths.sort()

    // Only send to the first non-spec window created
    if (includeShellLoadTime && !this.isSpec) {
      includeShellLoadTime = false
      if (!this.loadSettings.shellLoadTime) {
        this.loadSettings.shellLoadTime = Date.now() - global.shellStartTime
      }
    }

    this.representedDirectoryPaths = this.loadSettings.initialPaths
    if (!this.loadSettings.env) this.env = this.loadSettings.env

    this.browserWindow.on('window:loaded', () => {
      this.disableZoom()
      this.emit('window:loaded')
      this.resolveLoadedPromise()
    })

    this.browserWindow.on('window:locations-opened', () => {
      this.emit('window:locations-opened')
    })

    this.browserWindow.on('enter-full-screen', () => {
      this.browserWindow.webContents.send('did-enter-full-screen')
    })

    this.browserWindow.on('leave-full-screen', () => {
      this.browserWindow.webContents.send('did-leave-full-screen')
    })

    this.browserWindow.loadURL(
      url.format({
        protocol: 'file',
        pathname: `${this.resourcePath}/static/index.html`,
        slashes: true
      })
    )

    this.browserWindow.showSaveDialog = this.showSaveDialog.bind(this)

    if (this.isSpec) this.browserWindow.focusOnWebView()

    const hasPathToOpen = !(locationsToOpen.length === 1 && locationsToOpen[0].pathToOpen == null)
    if (hasPathToOpen && !this.isSpecWindow()) this.openLocations(locationsToOpen)
  }

  hasProjectPath () {
    return this.representedDirectoryPaths.length > 0
  }

  setupContextMenu () {
    const ContextMenu = require('./context-menu')

    this.browserWindow.on('context-menu', menuTemplate => {
      return new ContextMenu(menuTemplate, this)
    })
  }

  containsPaths (paths) {
    return paths.every(p => this.containsPath(p))
  }

  containsPath (pathToCheck) {
    if (!pathToCheck) return false
    const stat = fs.statSyncNoException(pathToCheck)
    if (stat && stat.isDirectory()) return false

    return this.representedDirectoryPaths.some(projectPath =>
      pathToCheck === projectPath || pathToCheck.startsWith(path.join(projectPath, path.sep))
    )
  }

  handleEvents () {
    this.browserWindow.on('close', async event => {
      if (!this.atomApplication.quitting && !this.unloading) {
        event.preventDefault()
        this.unloading = true
        this.atomApplication.saveCurrentWindowOptions(false)
        if (await this.prepareToUnload()) this.close()
      }
    })

    this.browserWindow.on('closed', () => {
      this.fileRecoveryService.didCloseWindow(this)
      this.atomApplication.removeWindow(this)
      this.resolveClosedPromise()
    })

    this.browserWindow.on('unresponsive', () => {
      if (this.isSpec) return
      dialog.showMessageBox(this.browserWindow, {
        type: 'warning',
        buttons: ['Force Close', 'Keep Waiting'],
        message: 'Editor is not responding',
        detail:
          'The editor is not responding. Would you like to force close it or just keep waiting?'
      }, response => { if (response === 0) this.browserWindow.destroy() })
    })

    this.browserWindow.webContents.on('crashed', async () => {
      if (this.headless) {
        console.log('Renderer process crashed, exiting')
        this.atomApplication.exit(100)
        return
      }

      await this.fileRecoveryService.didCrashWindow(this)
      dialog.showMessageBox(this.browserWindow, {
        type: 'warning',
        buttons: ['Close Window', 'Reload', 'Keep It Open'],
        message: 'The editor has crashed',
        detail: 'Please report this issue to https://github.com/atom/atom'
      }, response => {
        switch (response) {
          case 0: return this.browserWindow.destroy()
          case 1: return this.browserWindow.reload()
        }
      })
    })

    this.browserWindow.webContents.on('will-navigate', (event, url) => {
      if (url !== this.browserWindow.webContents.getURL()) event.preventDefault()
    })

    this.setupContextMenu()

    // Spec window's web view should always have focus
    if (this.isSpec) this.browserWindow.on('blur', () => this.browserWindow.focusOnWebView())
  }

  async prepareToUnload () {
    if (this.isSpecWindow()) return true

    this.lastPrepareToUnloadPromise = new Promise(resolve => {
      const callback = (event, result) => {
        if (BrowserWindow.fromWebContents(event.sender) === this.browserWindow) {
          ipcMain.removeListener('did-prepare-to-unload', callback)
          if (!result) {
            this.unloading = false
            this.atomApplication.quitting = false
          }
          resolve(result)
        }
      }
      ipcMain.on('did-prepare-to-unload', callback)
      this.browserWindow.webContents.send('prepare-to-unload')
    })

    return this.lastPrepareToUnloadPromise
  }

  openPath (pathToOpen, initialLine, initialColumn) {
    return this.openLocations([{pathToOpen, initialLine, initialColumn}])
  }

  async openLocations (locationsToOpen) {
    await this.loadedPromise
    this.sendMessage('open-locations', locationsToOpen)
  }

  didChangeUserSettings (settings) {
    this.sendMessage('did-change-user-settings', settings)
  }

  didFailToReadUserSettings (message) {
    this.sendMessage('did-fail-to-read-user-settings', message)
  }

  replaceEnvironment (env) {
    this.browserWindow.webContents.send('environment', env)
  }

  sendMessage (message, detail) {
    this.browserWindow.webContents.send('message', message, detail)
  }

  sendCommand (command, ...args) {
    if (this.isSpecWindow()) {
      if (!this.atomApplication.sendCommandToFirstResponder(command)) {
        switch (command) {
          case 'window:reload': return this.reload()
          case 'window:toggle-dev-tools': return this.toggleDevTools()
          case 'window:close': return this.close()
        }
      }
    } else if (this.isWebViewFocused()) {
      this.sendCommandToBrowserWindow(command, ...args)
    } else if (!this.atomApplication.sendCommandToFirstResponder(command)) {
      this.sendCommandToBrowserWindow(command, ...args)
    }
  }

  sendURIMessage (uri) {
    this.browserWindow.webContents.send('uri-message', uri)
  }

  sendCommandToBrowserWindow (command, ...args) {
    const action = args[0] && args[0].contextCommand
      ? 'context-command'
      : 'command'
    this.browserWindow.webContents.send(action, command, ...args)
  }

  getDimensions () {
    const [x, y] = Array.from(this.browserWindow.getPosition())
    const [width, height] = Array.from(this.browserWindow.getSize())
    return {x, y, width, height}
  }

  shouldAddCustomTitleBar () {
    return (
      !this.isSpec &&
      process.platform === 'darwin' &&
      this.atomApplication.config.get('core.titleBar') === 'custom'
    )
  }

  shouldAddCustomInsetTitleBar () {
    return (
      !this.isSpec &&
      process.platform === 'darwin' &&
      this.atomApplication.config.get('core.titleBar') === 'custom-inset'
    )
  }

  shouldHideTitleBar () {
    return (
      !this.isSpec &&
      process.platform === 'darwin' &&
      this.atomApplication.config.get('core.titleBar') === 'hidden'
    )
  }

  close () {
    return this.browserWindow.close()
  }

  focus () {
    return this.browserWindow.focus()
  }

  minimize () {
    return this.browserWindow.minimize()
  }

  maximize () {
    return this.browserWindow.maximize()
  }

  unmaximize () {
    return this.browserWindow.unmaximize()
  }

  restore () {
    return this.browserWindow.restore()
  }

  setFullScreen (fullScreen) {
    return this.browserWindow.setFullScreen(fullScreen)
  }

  setAutoHideMenuBar (autoHideMenuBar) {
    return this.browserWindow.setAutoHideMenuBar(autoHideMenuBar)
  }

  handlesAtomCommands () {
    return !this.isSpecWindow() && this.isWebViewFocused()
  }

  isFocused () {
    return this.browserWindow.isFocused()
  }

  isMaximized () {
    return this.browserWindow.isMaximized()
  }

  isMinimized () {
    return this.browserWindow.isMinimized()
  }

  isWebViewFocused () {
    return this.browserWindow.isWebViewFocused()
  }

  isSpecWindow () {
    return this.isSpec
  }

  reload () {
    this.loadedPromise = new Promise(resolve => { this.resolveLoadedPromise = resolve })
    this.prepareToUnload().then(canUnload => {
      if (canUnload) this.browserWindow.reload()
    })
    return this.loadedPromise
  }

  showSaveDialog (options, callback) {
    options = Object.assign({
      title: 'Save File',
      defaultPath: this.representedDirectoryPaths[0]
    }, options)

    if (typeof callback === 'function') {
      // Async
      dialog.showSaveDialog(this.browserWindow, options, callback)
    } else {
      // Sync
      return dialog.showSaveDialog(this.browserWindow, options)
    }
  }

  toggleDevTools () {
    return this.browserWindow.toggleDevTools()
  }

  openDevTools () {
    return this.browserWindow.openDevTools()
  }

  closeDevTools () {
    return this.browserWindow.closeDevTools()
  }

  setDocumentEdited (documentEdited) {
    return this.browserWindow.setDocumentEdited(documentEdited)
  }

  setRepresentedFilename (representedFilename) {
    return this.browserWindow.setRepresentedFilename(representedFilename)
  }

  setRepresentedDirectoryPaths (representedDirectoryPaths) {
    this.representedDirectoryPaths = representedDirectoryPaths
    this.representedDirectoryPaths.sort()
    this.loadSettings.initialPaths = this.representedDirectoryPaths
    return this.atomApplication.saveCurrentWindowOptions()
  }

  didClosePathWithWaitSession (path) {
    this.atomApplication.windowDidClosePathWithWaitSession(this, path)
  }

  copy () {
    return this.browserWindow.copy()
  }

  disableZoom () {
    return this.browserWindow.webContents.setVisualZoomLevelLimits(1, 1)
  }
}
