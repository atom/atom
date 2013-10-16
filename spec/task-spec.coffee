Task = require '../src/task'

describe "Task", ->
  describe "@once(taskPath, args..., callback)", ->
    it "terminates the process after it completes", ->
      handlerResult = null
      task = Task.once require.resolve('./fixtures/task-spec-handler'), (result) ->
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
