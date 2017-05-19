Task = require './task'

handlerInstance = null

startHandler = ->
  if not handlerInstance?
    handlerInstance = new Task require.resolve('./repository-status-handler')
    handlerInstance.start()

terminateHandler = ->
  if handlerInstance?
    handlerInstance.terminate()
    handlerInstance = null

refreshStatus = (repoPath, paths) ->
  startHandler()
  new Promise (resolve) ->
    responseSub = handlerInstance.on repoPath, (result) ->
      responseSub.dispose()
      resolve(result)

    handlerInstance.send {repoPath, paths}

module.exports = {
  terminateHandler,
  refreshStatus
}
