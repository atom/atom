TextMateBundle = require("text-mate-bundle")
fs = require 'fs'
_ = require 'underscore'
Package = require 'package'
TextMatePackage = require 'text-mate-package'

messageIdCounter = 1
originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

_.extend atom,
  exitWhenDone: window.location.params.exitWhenDone

  pendingBrowserProcessCallbacks: {}

  getAvailablePackages: ->
    allPackageNames = []
    for packageDirPath in config.packageDirPaths
      packageNames = fs.list(packageDirPath)
        .filter((packagePath) -> fs.isDirectory(packagePath))
        .map((packagePath) -> fs.base(packagePath))
      allPackageNames.push(packageNames...)
    _.unique(allPackageNames)

  getAvailableTextMateBundles: ->
    @getAvailablePackages().filter (packageName) => TextMatePackage.testName(packageName)

  loadPackages: (packageNames=@getAvailablePackages()) ->
    disabledPackages = config.get("core.disabledPackages") ? []
    for packageName in packageNames
      @loadPackage(packageName) unless _.contains(disabledPackages, packageName)

  loadPackage: (name) ->
    Package.forName(name).load()

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
