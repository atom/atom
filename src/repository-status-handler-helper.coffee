Task = require './task'

handlerInstance = null

startHandler = ->
  new Promise (resolve) ->
    window.requestIdleCallback ->
      if not handlerInstance?
        handlerInstance = new Task require.resolve('./repository-status-handler')
        handlerInstance.start()
      resolve()

terminateHandler = ->
  window.requestIdleCallback ->
    if handlerInstance?
      handlerInstance.terminate()
      handlerInstance = null

refreshStatus = (repoPath, paths) ->
  startHandler().then ->
    new Promise (resolve) ->
      window.requestIdleCallback ->
        responseSub = handlerInstance.on repoPath, (result) ->
          responseSub.dispose()
          resolve(result)

        handlerInstance.send {repoPath, paths}

module.exports = {
  terminateHandler,
  refreshStatus
}
