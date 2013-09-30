fsUtils = require './fs-utils'
$ = require './jquery-extensions'
_ = require './underscore-extensions'
Package = require './package'
ipc = require 'ipc'
remote = require 'remote'
shell = require 'shell'
crypto = require 'crypto'
path = require 'path'
dialog = remote.require 'dialog'
app = remote.require 'app'
{Document} = require 'telepath'
ThemeManager = require './theme-manager'
ContextMenuManager = require './context-menu-manager'

window.atom =
  loadedPackages: {}
  activePackages: {}
  packageStates: {}
  themes: new ThemeManager()
  contextMenu: new ContextMenuManager(remote.getCurrentWindow().loadSettings.devMode)

  getLoadSettings: ->
    @getCurrentWindow().loadSettings

  getCurrentWindow: ->
    remote.getCurrentWindow()

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
    # Ensure atom exports is already in the require cache so the load time
    # of the first package isn't skewed by being the first to require atom
    require '../exports/atom'

    @loadPackage(name) for name in @getAvailablePackageNames() when not @isPackageDisabled(name)
    @watchThemes()

  loadPackage: (name, options) ->
    if @isPackageDisabled(name)
      return console.warn("Tried to load disabled package '#{name}'")

    if packagePath = @resolvePackagePath(name)
      return pack if pack = @getLoadedPackage(name)
      pack = Package.load(packagePath, options)
      if pack.metadata.theme
        @themes.register(pack)
      else
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

  loadThemes: ->
    @themes.load()

  watchThemes: ->
    @themes.on 'reloaded', =>
      @reloadBaseStylesheets()
      pack.reloadStylesheets?() for name, pack of @loadedPackages
      null

  loadBaseStylesheets: ->
    requireStylesheet('bootstrap/less/bootstrap')
    @reloadBaseStylesheets()

  reloadBaseStylesheets: ->
    requireStylesheet('../static/atom')
    if nativeStylesheetPath = fsUtils.resolveOnLoadPath(process.platform, ['css', 'less'])
      requireStylesheet(nativeStylesheetPath)

  open: (options) ->
    ipc.sendChannel('open', options)

  confirm: (message, detailedMessage, buttonLabelsAndCallbacks...) ->
    buttons = []
    callbacks = []
    while buttonLabelsAndCallbacks.length
      do =>
        buttons.push buttonLabelsAndCallbacks.shift()
        callbacks.push buttonLabelsAndCallbacks.shift()

    chosen = @confirmSync(message, detailedMessage, buttons)
    callbacks[chosen]?()

  confirmSync: (message, detailedMessage, buttons, browserWindow=@getCurrentWindow()) ->
    dialog.showMessageBox browserWindow,
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttons

  showSaveDialog: (callback) ->
    callback(showSaveDialogSync())

  showSaveDialogSync: (defaultPath) ->
    defaultPath ?= project?.getPath()
    currentWindow = @getCurrentWindow()
    dialog.showSaveDialog currentWindow, {title: 'Save File', defaultPath}

  openDevTools: ->
    @getCurrentWindow().openDevTools()

  toggleDevTools: ->
    @getCurrentWindow().toggleDevTools()

  reload: ->
    @getCurrentWindow().restart()

  focus: ->
    @getCurrentWindow().focus()
    $(window).focus()

  show: ->
    @getCurrentWindow().show()

  hide: ->
    @getCurrentWindow().hide()

  close: ->
    @getCurrentWindow().close()

  exit: (status) ->
    app.exit(status)

  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  setFullScreen: (fullScreen=false) ->
    @getCurrentWindow().setFullScreen(fullScreen)

  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

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
          documentStateJson  = fsUtils.read(windowStatePath)
        catch error
          console.warn "Error reading window state: #{windowStatePath}", error.stack, error
    else
      documentStateJson = @getLoadSettings().windowState

    try
      documentState = JSON.parse(documentStateJson) if documentStateJson?
    catch error
      console.warn "Error parsing window state: #{windowStatePath}", error.stack, error

    doc = Document.deserialize(state: documentState) if documentState?
    doc ?= Document.create()
    window.site = doc.site # TODO: Remove this when everything is using telepath models
    doc

  saveWindowState: ->
    windowState = @getWindowState()
    if windowStatePath = @getWindowStatePath()
      windowState.saveSync(path: windowStatePath)
    else
      @getLoadSettings().windowState = JSON.stringify(windowState.serialize())

  getWindowState: (keyPath) ->
    @windowState ?= @loadWindowState()
    if keyPath
      @windowState.get(keyPath)
    else
      @windowState

  crashMainProcess: ->
    remote.process.crash()

  crashRenderProcess: ->
    process.crash()

  beep: ->
    shell.beep()

  requireUserInitScript: ->
    userInitScriptPath = path.join(config.configDirPath, "user.coffee")
    try
      require userInitScriptPath if fsUtils.isFileSync(userInitScriptPath)
    catch error
      console.error "Failed to load `#{userInitScriptPath}`", error.stack, error
