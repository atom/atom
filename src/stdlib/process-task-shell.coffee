global.window = {}
global.attachEvent = ->
console =
  warn: -> callTaskMethod 'warn', arguments...
  log: -> callTaskMethod 'log', arguments...
  error: -> callTaskMethod 'error', arguments...
global.__defineGetter__ 'console', -> console

window.document =
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
global.document = window.document

# `callTaskMethod` can be used to invoke method's on the parent `Task` object
# back in the window thread.
global.callTaskMethod = (method, args...) ->
  process.send(method: method, args: args)

# The worker's initial handler replaces itglobal when `start` is invoked
global.handler =
  start: ({globals, handlerPath}) ->
    for key, value of globals
      global[key] = value
      window[key] = value
    global.handler = require(handlerPath)
    callTaskMethod 'started'

process.on 'message', (data) ->
  handler[data.method]?(data.args...) if data.method
