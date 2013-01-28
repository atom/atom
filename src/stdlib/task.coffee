module.exports =
class Task
  constructor: (@path) ->

  start: ->
    @worker = new Worker(require.getPath('task-shell'))
    @worker.onmessage = ({data}) =>
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
      resourcePath: window.resourcePath
      requirePath: require.getPath('require')
      handlerPath: @path

  started: ->

  onMessage: (message) ->

  callWorkerMethod: (method, args...) ->
    @postMessage({method, args})

  postMessage: (data) ->
    @worker.postMessage(data)

  terminate: ->
    @worker.terminate()
