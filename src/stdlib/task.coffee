_ = require 'underscore'
EventEmitter = require 'event-emitter'

module.exports =
class Task
  aborted: false

  constructor: (@path) ->

  start: ->
    throw new Error("Task already started") if @worker?

    @worker = new Worker(require.getPath('task-shell'))
    @worker.onmessage = ({data}) =>
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
        resourcePath: window.resourcePath
        navigator:
          userAgent: navigator.userAgent
      requirePath: require.getPath('require')
      handlerPath: @path

  started: ->

  onMessage: (message) ->

  callWorkerMethod: (method, args...) ->
    @postMessage({method, args})

  postMessage: (data) ->
    @worker.postMessage(data)

  abort: ->
    @aborted = true

  done: ->
    @abort()
    @worker?.terminate()
    @worker = null
    @trigger 'task-completed'

_.extend Task.prototype, EventEmitter
