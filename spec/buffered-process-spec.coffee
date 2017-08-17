ChildProcess = require 'child_process'
path = require 'path'
fs = require 'fs-plus'
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
          bufferedProcess = new BufferedProcess
            command: 'bad-command-nope1'
            args: ['nothing']
            options: {shell: false}

          errorSpy = jasmine.createSpy().andCallFake (error) -> error.handle()
          bufferedProcess.onWillThrowError(errorSpy)

          waitsFor -> errorSpy.callCount > 0

          runs ->
            expect(window.onerror).not.toHaveBeenCalled()
            expect(errorSpy).toHaveBeenCalled()
            expect(errorSpy.mostRecentCall.args[0].error.message).toContain 'spawn bad-command-nope1 ENOENT'

      describe "when an error is thrown spawning the process", ->
        it "calls the error handler and does not throw an exception", ->
          spyOn(ChildProcess, 'spawn').andCallFake ->
            error = new Error('Something is really wrong')
            error.code = 'EAGAIN'
            throw error

          bufferedProcess = new BufferedProcess
            command: 'ls'
            args: []
            options: {}

          errorSpy = jasmine.createSpy().andCallFake (error) -> error.handle()
          bufferedProcess.onWillThrowError(errorSpy)

          waitsFor -> errorSpy.callCount > 0

          runs ->
            expect(window.onerror).not.toHaveBeenCalled()
            expect(errorSpy).toHaveBeenCalled()
            expect(errorSpy.mostRecentCall.args[0].error.message).toContain 'Something is really wrong'

    describe "when there is not an error handler specified", ->
      it "does throw an exception", ->
        new BufferedProcess
          command: 'bad-command-nope2'
          args: ['nothing']
          options: {shell: false}

        waitsFor -> window.onerror.callCount > 0

        runs ->
          expect(window.onerror).toHaveBeenCalled()
          expect(window.onerror.mostRecentCall.args[0]).toContain 'Failed to spawn command `bad-command-nope2`'
          expect(window.onerror.mostRecentCall.args[4].name).toBe 'BufferedProcessError'

  it "calls the specified stdout, stderr, and exit callbacks", ->
    stdout = ''
    stderr = ''
    exitCallback = jasmine.createSpy('exit callback')
    new BufferedProcess
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

  it "calls the specified stdout callback with whole lines", ->
    exitCallback = jasmine.createSpy('exit callback')
    loremPath = require.resolve("./fixtures/lorem.txt")
    content = fs.readFileSync(loremPath).toString()
    baseContent = content.split('\n')
    stdout = ''
    allLinesEndWithNewline = true
    new BufferedProcess
      command: if process.platform is 'win32' then 'type' else 'cat'
      args: [loremPath]
      options: {}
      stdout: (lines) ->
        endsWithNewline = (lines.charAt lines.length - 1) is '\n'
        if not endsWithNewline then allLinesEndWithNewline = false
        stdout += lines
      exit: exitCallback

    waitsFor -> exitCallback.callCount is 1

    runs ->
      expect(allLinesEndWithNewline).toBeTrue
      expect(stdout).toBe content

  describe "on Windows", ->
    originalPlatform = null

    beforeEach ->
      # Prevent any commands from actually running and affecting the host
      originalSpawn = ChildProcess.spawn
      spyOn(ChildProcess, 'spawn')
      originalPlatform = process.platform
      Object.defineProperty process, 'platform', value: 'win32'

    afterEach ->
      Object.defineProperty process, 'platform', value: originalPlatform

    describe "when the explorer command is spawned on Windows", ->
      it "doesn't quote arguments of the form /root,C...", ->
        new BufferedProcess({command: 'explorer.exe', args: ['/root,C:\\foo']})
        expect(ChildProcess.spawn.argsForCall[0][1][3]).toBe '"explorer.exe /root,C:\\foo"'

    it "spawns the command using a cmd.exe wrapper when options.shell is undefined", ->
      new BufferedProcess({command: 'dir'})
      expect(path.basename(ChildProcess.spawn.argsForCall[0][0])).toBe 'cmd.exe'
      expect(ChildProcess.spawn.argsForCall[0][1][0]).toBe '/s'
      expect(ChildProcess.spawn.argsForCall[0][1][1]).toBe '/d'
      expect(ChildProcess.spawn.argsForCall[0][1][2]).toBe '/c'
      expect(ChildProcess.spawn.argsForCall[0][1][3]).toBe '"dir"'
