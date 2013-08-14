fsUtils = require 'fs-utils'
$ = require 'jquery'
_ = require 'underscore'
Package = require 'package'
ipc = require 'ipc'
remote = require 'remote'
crypto = require 'crypto'
path = require 'path'
dialog = remote.require 'dialog'
app = remote.require 'app'
telepath = require 'telepath'
ThemeManager = require 'theme-manager'

window.atom =
  loadedPackages: {}
  activePackages: {}
  packageStates: {}
  themes: new ThemeManager()

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

  loadPackages: ->
    @loadPackage(name) for name in @getAvailablePackageNames() when not @isPackageDisabled(name)
    @themes.on 'reload', =>
      pack.reloadStylesheets?() for name, pack of @loadedPackages
      null

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
    _.uniq _.map @getAvailablePackagePaths(), (packagePath) -> path.basename(packagePath)

  getAvailablePackageMetadata: ->
    packages = []
    for packagePath in atom.getAvailablePackagePaths()
      name = path.basename(packagePath)
      metadata = atom.getLoadedPackage(name)?.metadata ? Package.loadMetadata(packagePath, true)
      packages.push(metadata)
    packages

  open: (url...) ->
    ipc.sendChannel('open', [url...])

  openDev: (url...) ->
    ipc.sendChannel('open-dev', [url...])

  newWindow: ->
    ipc.sendChannel('new-window')

  openWindow: (windowSettings) ->
    ipc.sendChannel('open-window', windowSettings)

  confirm: (message, detailedMessage, buttonLabelsAndCallbacks...) ->
    buttons = []
    callbacks = []
    while buttonLabelsAndCallbacks.length
      do =>
        buttons.push buttonLabelsAndCallbacks.shift()
        callbacks.push buttonLabelsAndCallbacks.shift()

    chosen = @confirmSync(message, detailedMessage, buttons)
    callbacks[chosen]?()

  confirmSync: (message, detailedMessage, buttons, browserWindow = null) ->
    dialog.showMessageBox browserWindow,
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttons

  showSaveDialog: (callback) ->
    callback(showSaveDialogSync())

  showSaveDialogSync: (defaultPath) ->
    defaultPath ?= project?.getPath()
    currentWindow = remote.getCurrentWindow()
    dialog.showSaveDialog currentWindow, {title: 'Save File', defaultPath}

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
    app.exit(status)

  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  setFullScreen: (fullScreen=false) ->
    remote.getCurrentWindow().setFullScreen(fullScreen)

  isFullScreen: ->
    remote.getCurrentWindow().isFullScreen()

  getHomeDirPath: ->
    app.getHomeDir()

  getWindowStatePath: ->
    switch @windowMode
      when 'spec'
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
    site.deserializeDocument(windowState) ? site.createDocument({})

  saveWindowState: ->
    windowStateJson = JSON.stringify(@getWindowState().serialize(), null, 2)
    if windowStatePath = @getWindowStatePath()
      fsUtils.writeSync(windowStatePath, "#{windowStateJson}\n")
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
