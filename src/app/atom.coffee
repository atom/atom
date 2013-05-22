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
  pendingBrowserProcessCallbacks: {}
  loadedPackages: []
  activePackages: []
  packageStates: {}
  presentingModal: false
  pendingModals: [[]]
  messageIdCounter: 1
  originalSendMessageToBrowserProcess: -> console.log 'this methods needs to be replaced'

  getPathToOpen: ->
    window.location.params.pathToOpen

  getPackageState: (name) ->
    @packageStates[name]

  setPackageState: (name, state) ->
    @packageStates[name] = state

  activatePackages: ->
    @activatePackage(pack.path) for pack in @getLoadedPackages()

  activatePackage: (id, options) ->
    if pack = @loadPackage(id, options)
      @activePackages.push(pack)
      pack.activate(options)
      pack

  deactivatePackages: ->
    @deactivatePackage(pack.path) for pack in @getActivePackages()

  deactivatePackage: (id) ->
    if pack = @getActivePackage(id)
      @setPackageState(pack.name, state) if state = pack.serialize?()
      pack.deactivate()
      _.remove(@activePackages, pack)
    else
      throw new Error("No active package for id '#{id}'")

  getActivePackage: (id) ->
    if path = @resolvePackagePath(id)
      _.detect @activePackages, (pack) -> pack.path is path

  isPackageActive: (id) ->
    if path = @resolvePackagePath(id)
      _.detect @activePackages, (pack) -> pack.path is path

  getActivePackages: ->
    _.clone(@activePackages)

  activatePackageConfigs: ->
    @activatePackageConfig(pack.path) for pack in @getLoadedPackages()

  activatePackageConfig: (id, options) ->
    if pack = @loadPackage(id, options)
      @activePackages.push(pack)
      pack.activateConfig()
      pack

  loadPackages: ->
    @loadPackage(path) for path in @getAvailablePackagePaths() when not @isPackageDisabled(path)

  loadPackage: (id, options) ->
    if @isPackageDisabled(id)
      return console.warn("Tried to load disabled package '#{id}'")

    if path = @resolvePackagePath(id)
      return pack if pack = @getLoadedPackage(id)
      pack = Package.load(path, options)
      @loadedPackages.push(pack)
      pack
    else
      throw new Error("Could not resolve '#{id}' to a package path")

  resolvePackagePath: _.memoize (id) ->
    return id if fsUtils.isDirectory(id)
    path = fsUtils.resolve(config.packageDirPaths..., id)
    path if fsUtils.isDirectory(path)

  getLoadedPackage: (id) ->
    if path = @resolvePackagePath(id)
      _.detect @loadedPackages, (pack) -> pack.path is path

  isPackageLoaded: (id) ->
    @getLoadedPackage(id)?

  getLoadedPackages: ->
    _.clone(@loadedPackages)

  isPackageDisabled: (id) ->
    if path = @resolvePackagePath(id)
      _.include(config.get('core.disabledPackages') ? [], fsUtils.base(path))

  getAvailablePackagePaths: ->
    packagePaths = []
    for packageDirPath in config.packageDirPaths
      for packagePath in fsUtils.list(packageDirPath)
        packagePaths.push(packagePath) if fsUtils.isDirectory(packagePath)
    _.uniq(packagePaths)

  getAvailablePackageNames: ->
    fsUtils.base(path) for path in @getAvailablePackagePaths()

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

  open: (url) ->
    if url
      throw new Error('opening a url does not currently work', url)
    else
      ipc.sendChannel('open-folder')

  openDev: (url) ->
    console.error("atom.openDev does not work yet")

  newWindow: ->
    ipc.sendChannel('new-window')

  openConfig: ->
    @sendMessageToBrowserProcess('openConfig')

  restartRendererProcess: ->
    @sendMessageToBrowserProcess('restartRendererProcess')

  confirm: (message, detailedMessage, buttonLabelsAndCallbacks...) ->
    buttons = []
    callbacks = []
    while buttonLabelsAndCallbacks.length
      do =>
        buttons.push buttonLabelsAndCallbacks.shift()
        callbacks.push buttonLabelsAndCallbacks.shift()

    chosen = remote.require('dialog').showMessageBox
      type: 'info', message: message, detail: detailedMessage, buttons: buttons

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
    # TODO Restart renderer process when needed
    remote.getCurrentWindow().reloadIgnoringCache()

  focus: ->
    remote.getCurrentWindow().focus()

  exit: (status) ->
    @sendMessageToBrowserProcess('exit', [status])

  log: (message) ->
    @sendMessageToBrowserProcess('log', [message])

  beginTracing: ->
    @sendMessageToBrowserProcess('beginTracing')

  endTracing: ->
    @sendMessageToBrowserProcess('endTracing')

  toggleFullScreen: ->
    currentWindow = remote.getCurrentWindow()
    currentWindow.setFullscreen(!currentWindow.isFullscreen())

  sendMessageToBrowserProcess: (name, data=[], callbacks) ->
    throw new Error("sendMessageToBrowserProcess no longer works for #{name}")

  receiveMessageFromBrowserProcess: (name, data) ->
    switch name
      when 'reply'
        [messageId, callbackIndex] = data.shift()
        @pendingBrowserProcessCallbacks[messageId]?[callbackIndex]?(data...)
      when 'openPath'
        path = data[0]
        rootView?.open(path)

  getWindowStatePath: ->
    if not @getPathToOpen()
      'probably-a-spec-window'
    else
      shasum = crypto.createHash('sha1')
      shasum.update(@getPathToOpen())
      fsUtils.join(config.userStoragePath, shasum.digest('hex'))

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
    @sendMessageToBrowserProcess('update')

  getUpdateStatus: (callback) ->
    @sendMessageToBrowserProcess('getUpdateStatus', [], callback)

  crashMainProcess: ->
    @sendMessageToBrowserProcess('crash')

  crashRenderProcess: ->
    $native.crash()

  requireUserInitScript: ->
    userInitScriptPath = fsUtils.join(config.configDirPath, "user.coffee")
    try
      require userInitScriptPath if fsUtils.isFile(userInitScriptPath)
    catch error
      console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

  getVersion: (callback) ->
    @sendMessageToBrowserProcess('getVersion', null, callback)
