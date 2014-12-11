BufferedProcess  = require '../src/buffered-process'

describe "BufferedProcess", ->
  describe "when a bad command is specified", ->
    [oldOnError] = []
    beforeEach ->
      oldOnError = window.onerror
      window.onerror = jasmine.createSpy()

    afterEach ->
      window.onerror = oldOnError

    describe "when there is an error handler specified", ->
      it "calls the error handler and does not throw an exception", ->
        process = new BufferedProcess
          command: 'bad-command-nope'
          args: ['nothing']
          options: {}

        process.onDidThrowError errorSpy = jasmine.createSpy()

        waitsFor -> errorSpy.callCount > 0

        runs ->
          expect(window.onerror).not.toHaveBeenCalled()
          expect(errorSpy).toHaveBeenCalled()
          expect(errorSpy.mostRecentCall.args[0].message).toContain 'spawn bad-command-nope ENOENT'

    describe "when there is not an error handler specified", ->
      it "calls the error handler and does not throw an exception", ->
        process = new BufferedProcess
          command: 'bad-command-nope'
          args: ['nothing']
          options: {}

        waitsFor -> window.onerror.callCount > 0

        runs ->
          expect(window.onerror).toHaveBeenCalled()
          expect(window.onerror.mostRecentCall.args[0]).toContain 'Failed to spawn command `bad-command-nope`'
          expect(window.onerror.mostRecentCall.args[4].name).toBe 'BufferedProcessError'
