fs = require('fs')

atom.configDirPath = fs.absolute("~/.atom")
atom.configFilePath = fs.join(atom.configDirPath, "atom.coffee")

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
