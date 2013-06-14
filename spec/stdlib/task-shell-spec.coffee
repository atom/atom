Task = require 'task'

describe "Task shell", ->
  describe "populating the window with fake properties", ->
    describe "when jQuery is loaded in a child process", ->
      it "doesn't log to the console", ->
        spyOn(console, 'log')
        spyOn(console, 'error')
        spyOn(console, 'warn')

        task = new JQueryTask()
        task.start()

        waitsFor "child process to start and jquery to be required", 5000, ->
          task.jqueryLoaded

        runs ->
          expect(task.jqueryLoaded).toBeTruthy()
          expect(console.log).not.toHaveBeenCalled()
          expect(console.error).not.toHaveBeenCalled()
          expect(console.warn).not.toHaveBeenCalled()
