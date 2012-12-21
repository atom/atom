TextMateBundle = require("text-mate-bundle")
fs = require 'fs'
_ = require 'underscore'

messageIdCounter = 1
originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

_.extend atom,
  exitWhenDone: window.location.params.exitWhenDone

  pendingBrowserProcessCallbacks: {}

  getAvailablePackages: ->
    allPackageNames = []
    for packageDirPath in config.packageDirPaths
      packageNames = fs.list(packageDirPath).map (packagePath) -> fs.base(packagePath)
      allPackageNames.push(packageNames...)
    _.unique(allPackageNames)

  getAvailableTextMateBundles: ->
    @getAvailablePackages().filter (packageName) => @isTextMateBundle(packageName)

  loadPackages: (packageNames=@getAvailablePackages()) ->
    disabledPackages = config.get("core.disabledPackages") ? []

    console.log packageNames
    for packageName in packageNames
      @loadPackage(packageName) unless _.contains(disabledPackages, packageName)

  loadPackage: (name) ->
    try
      if @isTextMateBundle(name)
        TextMateBundle.load(name)
      else
        packagePath = require.resolve(name, verifyExistence: false)
        throw new Error("No package found named '#{name}'") unless packagePath
        packagePath = fs.directory(packagePath)
        packageModule = require(packagePath)
        packageModule.name = name
        rootView.activatePackage(packageModule)
        extensionKeymapPath = require.resolve(fs.join(name, "src/keymap"), verifyExistence: false)
        require extensionKeymapPath if fs.exists(extensionKeymapPath)
    catch e
      console.error "Failed to load package named '#{name}'", e.stack

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

  isTextMateBundle: (packageName) ->
    /(\.|_|-)tmbundle$/.test(packageName)
