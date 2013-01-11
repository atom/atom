fs = require 'fs'
_ = require 'underscore'
Package = require 'package'
TextMatePackage = require 'text-mate-package'
Theme = require 'theme'

messageIdCounter = 1
originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

_.extend atom,
  exitWhenDone: window.location.params.exitWhenDone

  pendingBrowserProcessCallbacks: {}

  loadPackages: ->
    pack.load() for pack in @getPackages()

  getPackages: ->
    @getPackageNames().map (name) -> Package.build(name)

  loadTextMatePackages: ->
    pack.load() for pack in @getTextMatePackages()

  getTextMatePackages: ->
    @getPackages().filter (pack) -> pack instanceof TextMatePackage

  loadPackage: (name) ->
    Package.build(name).load()

  getPackageNames: ->
    disabledPackages = config.get("core.disabledPackages") ? []
    allPackageNames = []
    for packageDirPath in config.packageDirPaths
      packageNames = fs.list(packageDirPath)
        .filter((packagePath) -> fs.isDirectory(packagePath))
        .map((packagePath) -> fs.base(packagePath))
      allPackageNames.push(packageNames...)
    _.unique(allPackageNames)
      .filter (name) -> not _.contains(disabledPackages, name)

  loadThemes: ->
    themeNames = config.get("core.themes") ? ['IR_Black']
    themeNames = [themeNames] unless _.isArray(themeNames)
    @loadTheme(themeName) for themeName in themeNames

  loadTheme: (name) ->
    Theme.load(name)

  open: (args...) ->
    @sendMessageToBrowserProcess('open', args)

  openUnstable: (args...) ->
    @sendMessageToBrowserProcess('openUnstable', args)

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

  exit: (status) ->
    @sendMessageToBrowserProcess('exit', [status])

  log: (message) ->
    @sendMessageToBrowserProcess('log', [message])

  beginTracing: ->
    @sendMessageToBrowserProcess('beginTracing')

  endTracing: ->
    @sendMessageToBrowserProcess('endTracing')

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
