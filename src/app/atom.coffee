messageIdCounter = 1

originalSendMessageToBrowserProcess = atom.sendMessageToBrowserProcess

atom.pendingBrowserProcessCallbacks = {}

atom.sendMessageToBrowserProcess = (name, data, callback) ->
  messageId = messageIdCounter++
  data.unshift(messageId)
  pendingBrowserProcessCallbacks[messageId] = callback

atom.open = (args...) ->
  @sendMessageToBrowserProcess('open', args)

atom.confirm = (prompt, buttonsAndCallbacks...) ->
  console.log prompt, buttonsAndCallbacks

atom.confirm "Are you sure?",
  "Yes", (-> )
  "No", (-> )
