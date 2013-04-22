fsUtils = require 'fs-utils'
_ = require 'underscore'
Package = require 'package'
Theme = require 'theme'

messageIdCounter = 1
originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

_.extend atom,
  exitWhenDone: window.location.params.exitWhenDone
  devMode: window.location.params.devMode
  loadedThemes: []
  pendingBrowserProcessCallbacks: {}
  loadedPackages: []
  activePackages: []
  packageStates: {}
  presentingModal: false
  pendingModals: [[]]

  getPathToOpen: ->
    @getWindowState('pathToOpen') ? window.location.params.pathToOpen

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
      return console.warn("Tried to load disabled packaged '#{id}'")

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

  open: (args...) ->
    @sendMessageToBrowserProcess('open', args)

  openDev: (args...) ->
    @sendMessageToBrowserProcess('openDev', args)

  newWindow: (args...) ->
    @sendMessageToBrowserProcess('newWindow', args)

  openConfig: ->
    @sendMessageToBrowserProcess('openConfig')

  restartRendererProcess: ->
    @sendMessageToBrowserProcess('restartRendererProcess')

  confirm: (message, detailedMessage, buttonLabelsAndCallbacks...) ->
    wrapCallback = (callback) => => @dismissModal(callback)
    @presentModal =>
      args = [message, detailedMessage]
      callbacks = []
      while buttonLabelsAndCallbacks.length
        do =>
          buttonLabel = buttonLabelsAndCallbacks.shift()
          buttonCallback = buttonLabelsAndCallbacks.shift()
          args.push(buttonLabel)
          callbacks.push(=> @dismissModal(buttonCallback))
      @sendMessageToBrowserProcess('confirm', args, callbacks)

  showSaveDialog: (callback) ->
    @presentModal =>
      @sendMessageToBrowserProcess('showSaveDialog', [], (path) => @dismissModal(callback, path))

  presentModal: (fn) ->
    if @presentingModal
      @pushPendingModal(fn)
    else
      @presentingModal = true
      fn()

  dismissModal: (fn, args...) ->
    @pendingModals.push([]) # prioritize any modals presented during dismiss callback
    fn?(args...)
    @presentingModal = false
    if fn = @shiftPendingModal()
      _.delay (=> @presentModal(fn)), 50 # let view update before next dialog

  pushPendingModal: (fn) ->
    # pendingModals is a stack of queues. enqueue to top of stack.
    stackSize = @pendingModals.length
    @pendingModals[stackSize - 1].push(fn)

  shiftPendingModal: ->
    # pop pendingModals stack if its top queue is empty, otherwise shift off the topmost queue
    stackSize = @pendingModals.length
    currentQueueSize = @pendingModals[stackSize - 1].length
    if stackSize > 1 and currentQueueSize == 0
      @pendingModals.pop()
      @shiftPendingModal()
    else
      @pendingModals[stackSize - 1].shift()

  toggleDevTools: ->
    @sendMessageToBrowserProcess('toggleDevTools')

  showDevTools: ->
    @sendMessageToBrowserProcess('showDevTools')

  focus: ->
    @sendMessageToBrowserProcess('focus')

  show: ->
    @sendMessageToBrowserProcess('show')

  exit: (status) ->
    @sendMessageToBrowserProcess('exit', [status])

  log: (message) ->
    @sendMessageToBrowserProcess('log', [message])

  beginTracing: ->
    @sendMessageToBrowserProcess('beginTracing')

  endTracing: ->
    @sendMessageToBrowserProcess('endTracing')

  toggleFullScreen: ->
    @sendMessageToBrowserProcess('toggleFullScreen')

  sendMessageToBrowserProcess: (name, data=[], callbacks) ->
    messageId = messageIdCounter++
    data.unshift(messageId)
    callbacks = [callbacks] if typeof callbacks is 'function'
    @pendingBrowserProcessCallbacks[messageId] = callbacks
    originalSendMessageToBrowserProcess(name, data)

  receiveMessageFromBrowserProcess: (name, data) ->
    switch name
      when 'reply'
        [messageId, callbackIndex] = data.shift()
        @pendingBrowserProcessCallbacks[messageId]?[callbackIndex]?(data...)
      when 'openPath'
        path = data[0]
        rootView?.open(path)

  setWindowState: (keyPath, value) ->
    windowState = @getWindowState()
    _.setValueForKeyPath(windowState, keyPath, value)
    $native.setWindowState(JSON.stringify(windowState))
    windowState

  getWindowState: (keyPath) ->
    windowState = JSON.parse(@getInMemoryWindowState() ? @getSavedWindowState() ? '{}')
    if keyPath
      _.valueForKeyPath(windowState, keyPath)
    else
      windowState

  getInMemoryWindowState: ->
    inMemoryState = $native.getWindowState()
    if inMemoryState.length > 0
      inMemoryState
    else
      null

  getSavedWindowState: ->
    storageKey = switch @windowMode
      when 'editor' then window.location.params.pathToOpen
      when 'config' then 'config'
    localStorage[storageKey] if storageKey

  saveWindowState: ->
    storageKey = switch @windowMode
      when 'editor' then @getPathToOpen()
      when 'config' then 'config'
    localStorage[storageKey] = JSON.stringify(@getWindowState())

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
