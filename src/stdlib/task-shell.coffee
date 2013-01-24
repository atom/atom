self.window = {}
self.attachEvent = ->
self.console =
  warn: ->
    self.postMessage
      type: 'warn'
      details: arguments
  log: ->
    self.postMessage
      type: 'log'
      details: arguments

self.addEventListener 'message', (event) ->
  switch event.data.type
    when 'start'
      window.resourcePath = event.data.resourcePath
      importScripts(event.data.requirePath)
      self.task = require(event.data.taskPath)
      self.postMessage(type:'started')
    else
      self.task[event.data.type](event.data)
