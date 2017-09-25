Task = require './task'

module.exports =
class StatusHandlerHelper
  terminateHandler: ->
    if @handlerInstance?
      @handlerInstance.terminate()
      @handlerInstance = null

  refreshStatus: (repoPath, paths) ->
    new Promise (resolve) =>
      responseSub = @getHandler().on repoPath, (result) ->
        responseSub.dispose()
        resolve(result)

      @getHandler().send {repoPath, paths}

  getHandler: ->
    if not @handlerInstance?
      @handlerInstance = new Task require.resolve('./repository-status-handler')
      terminatedSub = @handlerInstance.on "exit", =>
        terminatedSub.dispose()
        @handlerInstance = null
      @handlerInstance.start()

    @handlerInstance
