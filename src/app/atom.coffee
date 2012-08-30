fs = require('fs')

atom.configDirPath = fs.absolute("~/.atom")
atom.configFilePath = fs.join(atom.configDirPath, "atom.coffee")

messageIdCounter = 1
originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

atom.pendingBrowserProcessCallbacks = {}

atom.sendMessageToBrowserProcess = (name, data, callbacks) ->
  messageId = messageIdCounter++
  data.unshift(messageId)
  callbacks = [callbacks] if typeof callbacks is 'function'
  @pendingBrowserProcessCallbacks[messageId] = callbacks
  originalSendMessageToBrowserProcess(name, data)

atom.receiveMessageFromBrowserProcess = (name, data) ->
  if name is 'reply'
    [messageId, callbackIndex] = data.shift()
    @pendingBrowserProcessCallbacks[messageId]?[callbackIndex]?(data...)

atom.open = (args...) ->
  @sendMessageToBrowserProcess('open', args)

atom.newWindow = (args...) ->
  @sendMessageToBrowserProcess('newWindow', args)

atom.confirm = (message, detailedMessage, buttonLabelsAndCallbacks...) ->
  args = [message, detailedMessage]
  callbacks = []
  while buttonLabelsAndCallbacks.length
    args.push(buttonLabelsAndCallbacks.shift())
    callbacks.push(buttonLabelsAndCallbacks.shift())
  @sendMessageToBrowserProcess('confirm', args, callbacks)

atom.showSaveDialog = (callback) ->
  @sendMessageToBrowserProcess('showSaveDialog', [], callback)

atom.toggleDevTools = (args...)->
  @sendMessageToBrowserProcess('toggleDevTools', args)

atom.getRootViewStateForPath = (path) ->
  if json = localStorage[path]
    JSON.parse(json)

atom.setRootViewStateForPath = (path, state) ->
  return unless path
  if state?
    localStorage[path] = JSON.stringify(state)
  else
    delete localStorage[path]
