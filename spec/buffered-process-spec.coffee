ChildProcess = require 'child_process'
path = require 'path'
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

        errorSpy = jasmine.createSpy().andCallFake (error) -> error.handle()
        process.onWillThrowError(errorSpy)

        waitsFor -> errorSpy.callCount > 0

        runs ->
          expect(window.onerror).not.toHaveBeenCalled()
          expect(errorSpy).toHaveBeenCalled()
          expect(errorSpy.mostRecentCall.args[0].error.message).toContain 'spawn bad-command-nope ENOENT'

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

  describe "on Windows", ->
    originalPlatform = null

    beforeEach ->
      # Prevent any commands from actually running and affecting the host
      originalSpawn = ChildProcess.spawn
      spyOn(ChildProcess, 'spawn').andCallFake ->
        # Just spawn something that won't actually modify the host
        if originalPlatform is 'win32'
          originalSpawn('dir')
        else
          originalSpawn('ls')

      originalPlatform = process.platform
      Object.defineProperty process, 'platform', value: 'win32'

    afterEach ->
      Object.defineProperty process, 'platform', value: originalPlatform

    describe "when the explorer command is spawned on Windows", ->
      it "doesn't quote arguments of the form /root,C...", ->
        new BufferedProcess({command: 'explorer.exe', args: ['/root,C:\\foo']})
        expect(ChildProcess.spawn.argsForCall[0][1][2]).toBe '"explorer.exe /root,C:\\foo"'

    it "spawns the command using a cmd.exe wrapper", ->
      new BufferedProcess({command: 'dir'})
      expect(path.basename(ChildProcess.spawn.argsForCall[0][0])).toBe 'cmd.exe'
      expect(ChildProcess.spawn.argsForCall[0][1][0]).toBe '/s'
      expect(ChildProcess.spawn.argsForCall[0][1][1]).toBe '/c'
      expect(ChildProcess.spawn.argsForCall[0][1][2]).toBe '"dir"'
