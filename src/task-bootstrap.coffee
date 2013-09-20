{userAgent, taskPath} = process.env
handler = null

setupGlobals = ->
  global.attachEvent = ->
  console =
    warn: -> emit 'task:warn', arguments...
    log: -> emit 'task:log', arguments...
    error: -> emit 'task:error', arguments...
    trace: ->
  global.__defineGetter__ 'console', -> console

  global.document =
    createElement: ->
      setAttribute: ->
      getElementsByTagName: -> []
      appendChild: ->
    documentElement:
      insertBefore: ->
      removeChild: ->
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
