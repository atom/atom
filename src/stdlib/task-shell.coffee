# This file is loaded within Task's worker thread. It will attempt to invoke
# any message with a 'method' and 'args' key on the global `handler` object. The
# initial `handler` object contains the `start` method, which is called by the
# task itself to relay information from the window thread and bootstrap the
# worker's environment. The `start` method then replaces the handler with an
# object required from the given `handlerPath`.

self.window = {}
self.attachEvent = ->
self.console =
  warn: -> callTaskMethod 'warn', arguments...
  log: -> callTaskMethod 'log', arguments...
  error: -> callTaskMethod 'error', arguments...

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
self.document = window.document

# `callTaskMethod` can be used to invoke method's on the parent `Task` object
# back in the window thread.
self.callTaskMethod = (method, args...) ->
  postMessage(method: method, args: args)

# The worker's initial handler replaces itself when `start` is invoked
self.handler =
  start: ({resourcePath, globals, requirePath, handlerPath}) ->
    for key, value of globals
      self[key] = value
      window[key] = value
    importScripts(requirePath)
    require 'config'
    self.handler = require(handlerPath)
    callTaskMethod 'started'

self.addEventListener 'message', ({data}) ->
  handler[data.method]?(data.args...) if data.method
