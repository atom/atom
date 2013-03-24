_ = require 'underscore'
child_process = require 'child_process'
EventEmitter = require 'event-emitter'
fs = require 'fs-utils'

module.exports =
class ProcessTask
  aborted: false

  constructor: (@path) ->

  start: ->
    throw new Error("Task already started") if @worker?

    # Equivalent with node --eval "...".
    blob = "require('coffee-script'); require('task-shell');"
    @worker = child_process.fork '--eval', [ blob ], cwd: __dirname

    @worker.on 'message', (data) =>
      if @aborted
        @done()
        return

      if data.method and this[data.method]
        this[data.method](data.args...)
      else
        @onMessage(data)

    @startWorker()

  log: -> console.log(arguments...)
  warn: -> console.warn(arguments...)
  error: -> console.error(arguments...)

  startWorker: ->
    @callWorkerMethod 'start',
      globals:
        navigator:
          userAgent: navigator.userAgent
      handlerPath: @path

  started: ->

  onMessage: (message) ->

  callWorkerMethod: (method, args...) ->
    @postMessage({method, args})

  postMessage: (data) ->
    @worker.send(data)

  abort: ->
    @aborted = true

  done: ->
    @abort()
    @worker?.kill()
    @worker = null
    @trigger 'task-completed'

_.extend ProcessTask.prototype, EventEmitter
