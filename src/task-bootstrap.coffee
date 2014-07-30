{userAgent, taskPath} = process.env
handler = null

setupGlobals = ->
  global.attachEvent = -> return
  console =
    warn: -> emit 'task:warn', arguments...
    log: -> emit 'task:log', arguments...
    error: -> emit 'task:error', arguments...
    trace: -> return
  global.__defineGetter__ 'console', -> console

  global.document =
    createElement: ->
      setAttribute: -> return
      getElementsByTagName: -> []
      appendChild: -> return
    documentElement:
      insertBefore: -> return
      removeChild: -> return
    getElementById: -> {}
    createComment: -> {}
    createDocumentFragment: -> {}

  global.emit = (event, args...) ->
    process.send({event, args})
  global.navigator = {userAgent}
  global.window = global

handleEvents = ->
  process.on 'uncaughtException', (error) ->
    console.error(error.message, error.stack)
  process.on 'message', ({event, args}={}) ->
    return unless event is 'start'

    isAsync = false
    async = ->
      isAsync = true
      (result) ->
        emit('task:completed', result)
    result = handler.bind({async})(args...)
    emit('task:completed', result) unless isAsync

setupGlobals()
handleEvents()
handler = require(taskPath)
