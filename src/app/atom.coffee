fs = require 'fs'
_ = require 'underscore'
Package = require 'package'
TextMatePackage = require 'text-mate-package'
Theme = require 'theme'
LoadTextMatePackagesTask = require 'load-text-mate-packages-task'

messageIdCounter = 1
originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

_.extend atom,
  exitWhenDone: window.location.params.exitWhenDone
  loadedThemes: []
  pendingBrowserProcessCallbacks: {}
  loadedPackages: []
  activatedAtomPackages: []
  atomPackageStates: {}

  getPathToOpen: ->
    @getWindowState('pathToOpen') ? window.location.params.pathToOpen

  activateAtomPackage: (pack) ->
    @activatedAtomPackages.push(pack)
    pack.packageMain.activate(@atomPackageStates[pack.name] ? {})

  deactivateAtomPackages: ->
    pack.packageMain.deactivate?() for pack in @activatedAtomPackages
    @activatedAtomPackages = []

  serializeAtomPackages: ->
    packageStates = {}
    for pack in @loadedPackages
      if pack in @activatedAtomPackages
        try
          packageStates[pack.name] = pack.packageMain.serialize?()
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
    args = [message, detailedMessage]
    callbacks = []
    while buttonLabelsAndCallbacks.length
      args.push(buttonLabelsAndCallbacks.shift())
      callbacks.push(buttonLabelsAndCallbacks.shift())
    @sendMessageToBrowserProcess('confirm', args, callbacks)

  showSaveDialog: (callback) ->
    @sendMessageToBrowserProcess('showSaveDialog', [], callback)

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

  getRootViewStateForPath: (path) ->
    if json = localStorage[path]
      JSON.parse(json)

  setRootViewStateForPath: (path, state) ->
    return unless path
    if state?
      localStorage[path] = JSON.stringify(state)
    else
      delete localStorage[path]

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
    windowState = JSON.parse($native.getWindowState())
    if keyPath
      _.valueForKeyPath(windowState, keyPath)
    else
      windowState

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
