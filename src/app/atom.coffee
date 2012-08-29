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
  console.log "RECEIVE MESSAGE IN JS", name, data

atom.open = (args...) ->
  @sendMessageToBrowserProcess('open', args)

atom.newWindow = (args...) ->
  @sendMessageToBrowserProcess('newWindow', args)

atom.getRootViewStateForPath = (path) ->
  if json = localStorage[path]
    JSON.parse(json)

atom.setRootViewStateForPath = (path, state) ->
  return unless path
  if state?
    localStorage[path] = JSON.stringify(state)
  else
    delete localStorage[path]
