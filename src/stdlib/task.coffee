module.exports =
class Task
  terminated: false

  constructor: (@path) ->

  start: ->
    throw new Error("Task already started") if @worker?

    @worker = new Worker(require.getPath('task-shell'))
    @worker.onmessage = ({data}) =>
      return if @terminated
      if data.method and this[data.method]
        this[data.method](data.args...)
      else
        @onMessage(data)
    @startWorker()

  log: -> console.log(arguments...)
  warn: -> console.warn(arguments...)
  error: -> console.error(arguments...)

  startWorker: ->
    @callWorkerMethod 'start'
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

  terminate: ->
    unless @terminated
      @terminated = true
      @worker.terminate()
      @worker = null
