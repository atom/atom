Task = require 'task'

describe "Task", ->
  describe "populating the window with fake properties", ->
    describe "when jQuery is loaded in a child process", ->
      it "doesn't log to the console", ->
        spyOn(console, 'log')
        spyOn(console, 'error')
        spyOn(console, 'warn')

        jqueryTask = new Task('fixtures/jquery-task-handler')
        jqueryLoaded = false
        jqueryTask.start (loaded) -> jqueryLoaded = loaded

        waitsFor "child process to start and jquery to be required", 5000, ->
          jqueryLoaded

        runs ->
          expect(jqueryLoaded).toBeTruthy()
          expect(console.log).not.toHaveBeenCalled()
          expect(console.error).not.toHaveBeenCalled()
          expect(console.warn).not.toHaveBeenCalled()

  describe "@once(taskPath, args..., callback)", ->
    it "terminates the process after it completes", ->
      handlerResult = null
      task = Task.once 'fixtures/task-spec-handler', (result) ->
        handlerResult = result

      processClosed = false
      processErrored = false
      childProcess = task.childProcess
      spyOn(childProcess, 'kill').andCallThrough()
      task.childProcess.on 'error', -> processErrored = true

      waitsFor ->
        handlerResult?

      runs ->
        expect(handlerResult).toBe 'hello'
        expect(childProcess.kill).toHaveBeenCalled()
        expect(processErrored).toBe false
