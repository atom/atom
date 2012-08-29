messageIdCounter = 1

originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

atom.pendingBrowserProcessCallbacks = {}

atom.sendMessageToBrowserProcess = (name, data, callback) ->
  messageId = messageIdCounter++
  data.unshift(messageId)
  pendingBrowserProcessCallbacks[messageId] = callback
  originalSendMessageToBrowserProcess(name, data)

atom.receiveMessageFromBrowserProcess = (name, data) ->
  console.log "RECEIVE MESSAGE IN JS", name, data

atom.open = (args...) ->
  @sendMessageToBrowserProcess('open', args)

atom.confirm = (prompt, buttonsAndCallbacks...) ->
  console.log prompt, buttonsAndCallbacks

