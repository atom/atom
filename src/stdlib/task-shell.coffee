# This file is loaded within Task's worker process. It will attempt to invoke
# any message with a 'method' and 'args' key on the global `handler` object. The
# initial `handler` object contains the `start` method, which is called by the
# task itself to relay information from the window thread and bootstrap the
# worker's environment. The `start` method then replaces the handler with an
# object required from the given `handlerPath`.

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
