Task = require 'task'

describe "Task shell", ->
  describe "populating the window with fake properties", ->
    describe "when jQuery is loaded in a web worker", ->
      it "doesn't log to the console", ->
        spyOn(console, 'log')
        spyOn(console, 'error')
        spyOn(console, 'warn')
        class JQueryTask extends Task
          constructor: -> super('fixtures/jquery-task-handler.coffee')
          started: -> @callWorkerMethod('load')
          loaded: (@jqueryLoaded) ->

        task = new JQueryTask()
        task.start()
        waitsFor "web worker to start and jquery to be required", 5000, ->
          task.jqueryLoaded
        runs ->
          expect(task.jqueryLoaded).toBeTruthy()
          expect(console.log).not.toHaveBeenCalled()
          expect(console.error).not.toHaveBeenCalled()
          expect(console.warn).not.toHaveBeenCalled()
