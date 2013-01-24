module.exports =
class Task

  constructor: (@path) ->

  onProgress: (event) ->

  start: ->
    worker = new Worker(require.getPath('task-shell'))
    worker.onmessage = (event) =>
      switch event.data.type
        when 'warn'
          console.warn(event.data.details...)
          return
        when 'log'
          console.log(event.data.details...)
          return

      reply = @onProgress(event)
      worker.postMessage(reply) if reply

    worker.postMessage
      type: 'start'
      resourcePath: window.resourcePath
      requirePath: require.getPath('require')
      taskPath: @path
