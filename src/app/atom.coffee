fsUtils = require 'fs-utils'
_ = require 'underscore'
Package = require 'package'
Theme = require 'theme'
ipc = require 'ipc'
remote = require 'remote'
crypto = require 'crypto'

window.atom =
  exitWhenDone: window.location.params.exitWhenDone
  devMode: window.location.params.devMode
  loadedThemes: []
  loadedPackages: {}
  activePackages: {}
  packageStates: {}

  getPathToOpen: ->
    window.location.params.pathToOpen

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

    if path = @resolvePackagePath(name)
      return pack if pack = @getLoadedPackage(name)
      pack = Package.load(path, options)
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
    return name if fsUtils.isDirectory(name)

    path = fsUtils.resolve(config.packageDirPaths..., name)
    return path if fsUtils.isDirectory(path)

    packagePath = fsUtils.join(window.resourcePath, 'node_modules', name)
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
      for packagePath in fsUtils.list(packageDirPath)
        packagePaths.push(packagePath) if fsUtils.isDirectory(packagePath)

    for packagePath in fsUtils.list(fsUtils.join(window.resourcePath, 'node_modules'))
      packagePaths.push(packagePath) if @isInternalPackage(packagePath)

    _.uniq(packagePaths)

  getAvailablePackageNames: ->
    fsUtils.base(path) for path in @getAvailablePackagePaths()

  getAvailablePackageMetadata: ->
    packages = []
    for packagePath in atom.getAvailablePackagePaths()
      name = fsUtils.base(packagePath)
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
      themePaths.push(fsUtils.list(themeDirPath, ['', '.tmTheme', '.css', 'less'])...)
    _.uniq(themePaths)

  getAvailableThemeNames: ->
    fsUtils.base(path).split('.')[0] for path in @getAvailableThemePaths()

  loadTheme: (name) ->
    @loadedThemes.push Theme.load(name)

  loadUserStylesheet: ->
    userStylesheetPath = fsUtils.resolve(fsUtils.join(config.configDirPath, 'user'), ['css', 'less'])
    if fsUtils.isFile(userStylesheetPath)
      userStyleesheetContents = loadStylesheet(userStylesheetPath)
      applyStylesheet(userStylesheetPath, userStyleesheetContents, 'userTheme')

  getAtomThemeStylesheets: ->
    themeNames = config.get("core.themes") ? ['atom-dark-ui', 'atom-dark-syntax']
    themeNames = [themeNames] unless _.isArray(themeNames)

  open: (url...) ->
    ipc.sendChannel('open', [url...])

  openDev: (url) ->
    console.error("atom.openDev does not work yet")

  newWindow: ->
    ipc.sendChannel('new-window')

  openConfig: ->
    ipc.sendChannel('open-config')

  confirm: (message, detailedMessage, buttonLabelsAndCallbacks...) ->
    buttons = []
    callbacks = []
    while buttonLabelsAndCallbacks.length
      do =>
        buttons.push buttonLabelsAndCallbacks.shift()
        callbacks.push buttonLabelsAndCallbacks.shift()

    chosen = remote.require('dialog').showMessageBox
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttons

    callbacks[chosen]?()

  showSaveDialog: (callback) ->
    currentWindow = remote.getCurrentWindow()
    result = remote.require('dialog').showSaveDialog currentWindow, title: 'Save File'
    callback(result)

  openDevTools: ->
    remote.getCurrentWindow().openDevTools()

  toggleDevTools: ->
    remote.getCurrentWindow().toggleDevTools()

  reload: ->
    remote.getCurrentWindow().restart()

  focus: ->
    remote.getCurrentWindow().focus()

  hide: ->
    remote.getCurrentWindow().hide()

  exit: (status) ->
    remote.require('app').exit(status)

  toggleFullScreen: ->
    currentWindow = remote.getCurrentWindow()
    currentWindow.setFullscreen(!currentWindow.isFullscreen())

  sendMessageToBrowserProcess: (name, data=[], callbacks) ->
    throw new Error("sendMessageToBrowserProcess no longer works for #{name}")

  getWindowStatePath: ->
    if @windowMode is 'config'
      filename = 'config'
    else if @windowMode is 'editor' and @getPathToOpen()
      shasum = crypto.createHash('sha1')
      shasum.update(@getPathToOpen())
      filename = "editor-#{shasum.digest('hex')}"
    else
      filename = 'undefined'

    fsUtils.join(config.userStoragePath, filename)

  setWindowState: (keyPath, value) ->
    windowState = @getWindowState()
    _.setValueForKeyPath(windowState, keyPath, value)
    fsUtils.write(@getWindowStatePath(), JSON.stringify(windowState))
    windowState

  getWindowState: (keyPath) ->
    return {} unless fsUtils.exists(@getWindowStatePath())

    windowState = JSON.parse(fsUtils.read(@getWindowStatePath()) or '{}')
    if keyPath
      _.valueForKeyPath(windowState, keyPath)
    else
      windowState

  update: ->
    ipc.sendChannel 'install-update'

  getUpdateStatus: (callback) ->
    throw new Error('atom.getUpdateStatus is not implemented')

  crashMainProcess: ->
    remote.process.crash()

  crashRenderProcess: ->
    process.crash()

  requireUserInitScript: ->
    userInitScriptPath = fsUtils.join(config.configDirPath, "user.coffee")
    try
      require userInitScriptPath if fsUtils.isFile(userInitScriptPath)
    catch error
      console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

  getVersion: ->
    ipc.sendChannelSync 'get-version'
