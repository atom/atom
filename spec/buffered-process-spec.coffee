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
      describe "when an error event is emitted by the process", ->
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

      describe "when an error is thrown spawning the process", ->
        it "calls the error handler and does not throw an exception", ->
          spyOn(ChildProcess, 'spawn').andCallFake ->
            error = new Error('Something is really wrong')
            error.code = 'EAGAIN'
            throw error

          process = new BufferedProcess
            command: 'ls'
            args: []
            options: {}

          errorSpy = jasmine.createSpy().andCallFake (error) -> error.handle()
          process.onWillThrowError(errorSpy)

          waitsFor -> errorSpy.callCount > 0

          runs ->
            expect(window.onerror).not.toHaveBeenCalled()
            expect(errorSpy).toHaveBeenCalled()
            expect(errorSpy.mostRecentCall.args[0].error.message).toContain 'Something is really wrong'

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
        expect(ChildProcess.spawn.argsForCall[0][1][3]).toBe '"explorer.exe /root,C:\\foo"'

    it "spawns the command using a cmd.exe wrapper", ->
      new BufferedProcess({command: 'dir'})
      expect(path.basename(ChildProcess.spawn.argsForCall[0][0])).toBe 'cmd.exe'
      expect(ChildProcess.spawn.argsForCall[0][1][0]).toBe '/s'
      expect(ChildProcess.spawn.argsForCall[0][1][1]).toBe '/d'
      expect(ChildProcess.spawn.argsForCall[0][1][2]).toBe '/c'
      expect(ChildProcess.spawn.argsForCall[0][1][3]).toBe '"dir"'

  it "calls the specified stdout, stderr, and exit callbacks", ->
    stdout = ''
    stderr = ''
    exitCallback = jasmine.createSpy('exit callback')
    process = new BufferedProcess
      command: atom.packages.getApmPath()
      args: ['-h']
      options: {}
      stdout: (lines) -> stdout += lines
      stderr: (lines) -> stderr += lines
      exit: exitCallback

    waitsFor -> exitCallback.callCount is 1

    runs ->
      expect(stderr).toContain 'apm - Atom Package Manager'
      expect(stdout).toEqual ''

  it "calls the specified stdout callback only with whole lines", ->
    exitCallback = jasmine.createSpy('exit callback')
    baseContent = "There are dozens of us! Dozens! It's as Ann as the nose on Plain's face. Can you believe that the only reason the club is going under is because it's in a terrifying neighborhood? She calls it a Mayonegg. Waiting for the Emmys. BTW did you know won 6 Emmys and was still canceled early by Fox? COME ON. I'll buy you a hundred George Michaels that you can teach to drive! Never once touched my per diem. I'd go to Craft Service, get some raw veggies, bacon, Cup-A-Soup…baby, I got a stew goin'"
    content = (baseContent for _ in [1..200]).join('\n')
    stdout = ''
    endLength = 10
    outputAlwaysEndsWithStew = true
    process = new BufferedProcess
      command: '/bin/echo'
      args: [content]
      options: {}
      stdout: (lines) ->
        stdout += lines

        end = baseContent.substr(baseContent.length - endLength, endLength)
        lineEndsWithStew = lines.substr(lines.length - endLength, endLength) is end
        expect(lineEndsWithStew).toBeTrue

        outputAlwaysEndsWithStew = outputAlwaysEndsWithStew and lineEndsWithStew
      exit: exitCallback

    waitsFor -> exitCallback.callCount is 1

    runs ->
      expect(outputAlwaysEndsWithStew).toBeTrue
      expect(stdout).toBe content += '\n'
