fsUtils = require 'fs-utils'
$ = require 'jquery'
_ = require 'underscore'
Package = require 'package'
Theme = require 'theme'
ipc = require 'ipc'
remote = require 'remote'
crypto = require 'crypto'
path = require 'path'
dialog = remote.require 'dialog'
telepath = require 'telepath'

window.atom =
  loadedThemes: []
  loadedPackages: {}
  activePackages: {}
  packageStates: {}

  getLoadSettings: ->
    remote.getCurrentWindow().loadSettings

  getPackageState: (name) ->
    @packageStates[name]

  setPackageState: (name, state) ->
    @packageStates[name] = state

  activatePackages: ->
    @activatePackage(pack.name) for pack in @getLoadedPackages()

  activatePackage: (name, options) ->
    if pack = @loadPackage(name, options)
      @activePackages[pack.name] = pack
      pack.activate(options)
      pack

  deactivatePackages: ->
    @deactivatePackage(pack.name) for pack in @getActivePackages()

  deactivatePackage: (name) ->
    if pack = @getActivePackage(name)
      @setPackageState(pack.name, state) if state = pack.serialize?()
      pack.deactivate()
      delete @activePackages[pack.name]
    else
      throw new Error("No active package for name '#{name}'")

  getActivePackage: (name) ->
    @activePackages[name]

  isPackageActive: (name) ->
    @getActivePackage(name)?

  getActivePackages: ->
    _.values(@activePackages)

  activatePackageConfigs: ->
    @activatePackageConfig(pack.name) for pack in @getLoadedPackages()

  activatePackageConfig: (name, options) ->
    if pack = @loadPackage(name, options)
      @activePackages[pack.name] = pack
      pack.activateConfig()
      pack

  loadPackages: ->
    @loadPackage(name) for name in @getAvailablePackageNames() when not @isPackageDisabled(name)

  loadPackage: (name, options) ->
    if @isPackageDisabled(name)
      return console.warn("Tried to load disabled package '#{name}'")

    if packagePath = @resolvePackagePath(name)
      return pack if pack = @getLoadedPackage(name)
      pack = Package.load(packagePath, options)
      @loadedPackages[pack.name] = pack
      pack
    else
      throw new Error("Could not resolve '#{name}' to a package path")

  unloadPackage: (name) ->
    if @isPackageActive(name)
      throw new Error("Tried to unload active package '#{name}'")

    if pack = @getLoadedPackage(name)
      delete @loadedPackages[pack.name]
    else
      throw new Error("No loaded package for name '#{name}'")

  resolvePackagePath: (name) ->
    return name if fsUtils.isDirectorySync(name)

    packagePath = fsUtils.resolve(config.packageDirPaths..., name)
    return packagePath if fsUtils.isDirectorySync(packagePath)

    packagePath = path.join(window.resourcePath, 'node_modules', name)
    return packagePath if @isInternalPackage(packagePath)

  isInternalPackage: (packagePath) ->
    {engines} = Package.loadMetadata(packagePath, true)
    engines?.atom?

  getLoadedPackage: (name) ->
    @loadedPackages[name]

  isPackageLoaded: (name) ->
    @getLoadedPackage(name)?

  getLoadedPackages: ->
    _.values(@loadedPackages)

  isPackageDisabled: (name) ->
    _.include(config.get('core.disabledPackages') ? [], name)

  getAvailablePackagePaths: ->
    packagePaths = []

    for packageDirPath in config.packageDirPaths
      for packagePath in fsUtils.listSync(packageDirPath)
        packagePaths.push(packagePath) if fsUtils.isDirectorySync(packagePath)

    for packagePath in fsUtils.listSync(path.join(window.resourcePath, 'node_modules'))
      packagePaths.push(packagePath) if @isInternalPackage(packagePath)

    _.uniq(packagePaths)

  getAvailablePackageNames: ->
    path.basename(packagePath) for packagePath in @getAvailablePackagePaths()

  getAvailablePackageMetadata: ->
    packages = []
    for packagePath in atom.getAvailablePackagePaths()
      name = path.basename(packagePath)
      metadata = atom.getLoadedPackage(name)?.metadata ? Package.loadMetadata(packagePath, true)
      packages.push(metadata)
    packages

  loadThemes: ->
    themeNames = config.get("core.themes")
    themeNames = [themeNames] unless _.isArray(themeNames)
    @loadTheme(themeName) for themeName in themeNames
    @loadUserStylesheet()

  getAvailableThemePaths: ->
    themePaths = []
    for themeDirPath in config.themeDirPaths
      themePaths.push(fsUtils.listSync(themeDirPath, ['', '.tmTheme', '.css', 'less'])...)
    _.uniq(themePaths)

  getAvailableThemeNames: ->
    path.basename(themePath).split('.')[0] for themePath in @getAvailableThemePaths()

  loadTheme: (name) ->
    @loadedThemes.push Theme.load(name)

  loadUserStylesheet: ->
    userStylesheetPath = fsUtils.resolve(path.join(config.configDirPath, 'user'), ['css', 'less'])
    if fsUtils.isFileSync(userStylesheetPath)
      userStyleesheetContents = loadStylesheet(userStylesheetPath)
      applyStylesheet(userStylesheetPath, userStyleesheetContents, 'userTheme')

  getAtomThemeStylesheets: ->
    themeNames = config.get("core.themes") ? ['atom-dark-ui', 'atom-dark-syntax']
    themeNames = [themeNames] unless _.isArray(themeNames)

  open: (url...) ->
    ipc.sendChannel('open', [url...])

  openDev: (url...) ->
    ipc.sendChannel('open-dev', [url...])

  newWindow: ->
    ipc.sendChannel('new-window')

  openConfig: ->
    ipc.sendChannel('open-config')

  openWindow: (windowSettings) ->
    ipc.sendChannel('open-window', windowSettings)

  confirm: (message, detailedMessage, buttonLabelsAndCallbacks...) ->
    buttons = []
    callbacks = []
    while buttonLabelsAndCallbacks.length
      do =>
        buttons.push buttonLabelsAndCallbacks.shift()
        callbacks.push buttonLabelsAndCallbacks.shift()

    chosen = confirmSync(message, detailedMessage, buttons)
    callbacks[chosen]?()

  confirmSync: (message, detailedMessage, buttons, browserWindow = null) ->
    dialog.showMessageBox browserWindow,
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttons

  showSaveDialog: (callback) ->
    callback(showSaveDialogSync())

  showSaveDialogSync: ->
    currentWindow = remote.getCurrentWindow()
    dialog.showSaveDialog currentWindow, title: 'Save File'

  openDevTools: ->
    remote.getCurrentWindow().openDevTools()

  toggleDevTools: ->
    remote.getCurrentWindow().toggleDevTools()

  reload: ->
    remote.getCurrentWindow().restart()

  focus: ->
    remote.getCurrentWindow().focus()
    $(window).focus()

  show: ->
    remote.getCurrentWindow().show()

  hide: ->
    remote.getCurrentWindow().hide()

  exit: (status) ->
    remote.require('app').exit(status)

  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  setFullScreen: (fullScreen=false) ->
    remote.getCurrentWindow().setFullScreen(fullScreen)

  isFullScreen: ->
    remote.getCurrentWindow().isFullScreen()

  getWindowStatePath: ->
    switch @windowMode
      when 'config', 'spec'
        filename = @windowMode
      when 'editor'
        {initialPath} = @getLoadSettings()
        if initialPath
          sha1 = crypto.createHash('sha1').update(initialPath).digest('hex')
          filename = "editor-#{sha1}"

    if filename
      path.join(config.userStoragePath, filename)
    else
      null

  setWindowState: (keyPath, value) ->
    windowState = @getWindowState()
    windowState.set(keyPath, value)
    windowState

  loadWindowState: ->
    if windowStatePath = @getWindowStatePath()
      if fsUtils.exists(windowStatePath)
        try
          windowStateJson  = fsUtils.read(windowStatePath)
        catch error
          console.warn "Error reading window state: #{windowStatePath}", error.stack, error
    else
      windowStateJson = @getLoadSettings().windowState

    try
      windowState = JSON.parse(windowStateJson or '{}')
    catch error
      console.warn "Error parsing window state: #{windowStatePath}", error.stack, error

    windowState ?= {}
    telepath.Document.create(windowState, site: telepath.createSite(1))

  saveWindowState: ->
    windowStateJson = JSON.stringify(@getWindowState().toObject())
    if windowStatePath = @getWindowStatePath()
      fsUtils.writeSync(windowStatePath, windowStateJson)
    else
      @getLoadSettings().windowState = windowStateJson

  getWindowState: (keyPath) ->
    @windowState ?= @loadWindowState()
    if keyPath
      @windowState.get(keyPath)
    else
      @windowState

  update: ->
    ipc.sendChannel 'install-update'

  crashMainProcess: ->
    remote.process.crash()

  crashRenderProcess: ->
    process.crash()

  requireUserInitScript: ->
    userInitScriptPath = path.join(config.configDirPath, "user.coffee")
    try
      require userInitScriptPath if fsUtils.isFileSync(userInitScriptPath)
    catch error
      console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

  getVersion: ->
    ipc.sendChannelSync 'get-version'
