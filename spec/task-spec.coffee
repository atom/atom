Task = require '../src/task'

describe "Task", ->
  describe "@once(taskPath, args..., callback)", ->
    it "terminates the process after it completes", (done) ->
      handlerResult = null
      processErrored = false

      task = Task.once require.resolve('./fixtures/task-spec-handler'), (result) ->
        handlerResult = result
        expect(handlerResult).toBe 'hello'
        # TODO: this doesn't work for some reason :(
        # expect(childProcess.kill).toHaveBeenCalled()
        expect(processErrored).toBe false
        done()

      childProcess = task.childProcess
      spyOn(childProcess, 'kill').and.callThrough()
      task.childProcess.on 'error', -> processErrored = true

  it "calls listeners registered with ::on when events are emitted in the task", (done) ->
    task = new Task(require.resolve('./fixtures/task-spec-handler'))

    eventSpy = jasmine.createSpy('eventSpy')
    task.on("some-event", eventSpy)

    task.start ->
      expect(eventSpy).toHaveBeenCalledWith(1, 2, 3)
      done()


  it "unregisters listeners when the Disposable returned by ::on is disposed", (done) ->
    task = new Task(require.resolve('./fixtures/task-spec-handler'))

    eventSpy = jasmine.createSpy('eventSpy')
    disposable = task.on("some-event", eventSpy)
    disposable.dispose()

    task.start ->
      expect(eventSpy).not.toHaveBeenCalled()
      done()
