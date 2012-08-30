fs = require('fs')

atom.configDirPath = fs.absolute("~/.atom")
atom.configFilePath = fs.join(atom.configDirPath, "atom.coffee")

messageIdCounter = 1
originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

atom.pendingBrowserProcessCallbacks = {}

atom.sendMessageToBrowserProcess = (name, data, callback) ->
  messageId = messageIdCounter++
  data.unshift(messageId)
  @pendingBrowserProcessCallbacks[messageId] = callback
  originalSendMessageToBrowserProcess(name, data)

atom.receiveMessageFromBrowserProcess = (name, data) ->
  if name is 'reply'
    [messageId, callbackIndex] = data
    @pendingBrowserProcessCallbacks[messageId]?[callbackIndex]?()

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
