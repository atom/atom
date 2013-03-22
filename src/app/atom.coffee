fs = require 'fs-utils'
_ = require 'underscore'
Package = require 'package'
TextMatePackage = require 'text-mate-package'
Theme = require 'theme'
LoadTextMatePackagesTask = require 'load-text-mate-packages-task'

messageIdCounter = 1
originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

_.extend atom,
  exitWhenDone: window.location.params.exitWhenDone
  devMode: window.location.params.devMode
  loadedThemes: []
  pendingBrowserProcessCallbacks: {}
  loadedPackages: []
  activatedAtomPackages: []
  atomPackageStates: {}
  presentingModal: false
  pendingModals: [[]]

  getPathToOpen: ->
    @getWindowState('pathToOpen') ? window.location.params.pathToOpen

  activateAtomPackage: (pack) ->
    @activatedAtomPackages.push(pack)
    pack.mainModule.activate(@atomPackageStates[pack.name] ? {})

  deactivateAtomPackages: ->
    pack.mainModule.deactivate?() for pack in @activatedAtomPackages
    @activatedAtomPackages = []

  serializeAtomPackages: ->
    packageStates = {}
    for pack in @loadedPackages
      if pack in @activatedAtomPackages
        try
          packageStates[pack.name] = pack.mainModule.serialize?()
        catch e
          console?.error("Exception serializing '#{pack.name}' package's module\n", e.stack)
      else
        packageStates[pack.name] = @atomPackageStates[pack.name]
    packageStates

  loadTextPackage: ->
    textPackagePath = _.find @getPackagePaths(), (path) -> fs.base(path) is 'text.tmbundle'
    pack = Package.build(textPackagePath)
    @loadedPackages.push(pack)
    pack.load()

  loadPackages: ->
    textMatePackages = []
    paths = @getPackagePaths().filter (path) -> fs.base(path) isnt 'text.tmbundle'
    for path in paths
      pack = Package.build(path)
      @loadedPackages.push(pack)
      if pack instanceof TextMatePackage
        textMatePackages.push(pack)
      else
        pack.load()

    new LoadTextMatePackagesTask(textMatePackages).start() if textMatePackages.length > 0

  activatePackages: ->
    pack.activate() for pack in @loadedPackages

  getLoadedPackages: ->
    _.clone(@loadedPackages)

  getPackagePaths: ->
    disabledPackages = config.get("core.disabledPackages") ? []
    packagePaths = []
    for packageDirPath in config.packageDirPaths
      for packagePath in fs.list(packageDirPath)
        continue if not fs.isDirectory(packagePath)
        continue if fs.base(packagePath) in disabledPackages
        continue if packagePath in packagePaths
        packagePaths.push(packagePath)

    packagePaths

  loadThemes: ->
    themeNames = config.get("core.themes") ? ['atom-dark-ui', 'atom-dark-syntax']
    themeNames = [themeNames] unless _.isArray(themeNames)
    @loadTheme(themeName) for themeName in themeNames
    @loadUserStylesheet()

  loadTheme: (name) ->
    @loadedThemes.push Theme.load(name)

  loadUserStylesheet: ->
    userStylesheetPath = fs.join(config.configDirPath, 'user.css')
    if fs.isFile(userStylesheetPath)
      applyStylesheet(userStylesheetPath, fs.read(userStylesheetPath), 'userTheme')

  getAtomThemeStylesheets: ->
    themeNames = config.get("core.themes") ? ['atom-dark-ui', 'atom-dark-syntax']
    themeNames = [themeNames] unless _.isArray(themeNames)

  open: (args...) ->
    @sendMessageToBrowserProcess('open', args)

  openDev: (args...) ->
    @sendMessageToBrowserProcess('openDev', args)

  newWindow: (args...) ->
    @sendMessageToBrowserProcess('newWindow', args)

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
    if name is 'reply'
      [messageId, callbackIndex] = data.shift()
      @pendingBrowserProcessCallbacks[messageId]?[callbackIndex]?(data...)

  setWindowState: (keyPath, value) ->
    windowState = @getWindowState()
    _.setValueForKeyPath(windowState, keyPath, value)
    $native.setWindowState(JSON.stringify(windowState))
    windowState

  getWindowState: (keyPath) ->
    inMemoryState = $native.getWindowState()
    inMemoryState = null unless inMemoryState.length > 0
    windowState = JSON.parse(inMemoryState ? localStorage[window.location.params.pathToOpen] ? '{}')
    if keyPath
      _.valueForKeyPath(windowState, keyPath)
    else
      windowState

  saveWindowState: ->
    localStorage[@getPathToOpen()] = JSON.stringify(@getWindowState())

  update: ->
    @sendMessageToBrowserProcess('update')

  getUpdateStatus: (callback) ->
    @sendMessageToBrowserProcess('getUpdateStatus', [], callback)

  requireUserInitScript: ->
    userInitScriptPath = fs.join(config.configDirPath, "user.coffee")
    try
      require userInitScriptPath if fs.isFile(userInitScriptPath)
    catch error
      console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

  getVersion: (callback) ->
    @sendMessageToBrowserProcess('getVersion', null, callback)
