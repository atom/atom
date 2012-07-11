ChildProcess = require 'child-process'

describe 'Child Processes', ->
  describe ".exec(command, options)", ->
    [stderrHandler, stdoutHandler] = []

    beforeEach ->
      stderrHandler = jasmine.createSpy "stderrHandler"
      stdoutHandler = jasmine.createSpy "stdoutHandler"

    it "returns a promise that resolves to stdout and stderr", ->
      waitsForPromise ->
        cmd = "echo 'good' && echo 'bad' >&2"
        ChildProcess.exec(cmd).done (stdout, stderr) ->
          expect(stdout).toBe 'good\n'
          expect(stderr).toBe 'bad\n'

    describe "when `options` contains stdout/stderror callbacks", ->
      it "calls the stdout callback when new data is received on stdout", ->
        cmd = "echo 'first' && sleep .1 && echo 'second' && sleep .1 && echo 'third'"
        ChildProcess.exec(cmd, stdout: stdoutHandler)

        waitsFor ->
          stdoutHandler.callCount > 2

        runs ->
          expect(stdoutHandler.argsForCall[0][0]).toBe "first\n"
          expect(stdoutHandler.argsForCall[1][0]).toBe "second\n"
          expect(stdoutHandler.argsForCall[2][0]).toBe "third\n"

      it "calls the stderr callback when new data is received on stderr", ->
        cmd = "echo '1111' >&2 && sleep .1 && echo '2222' >&2"
        ChildProcess.exec(cmd, stderr: stderrHandler)

        waitsFor ->
          stderrHandler.callCount > 1

        runs ->
          expect(stderrHandler.argsForCall[0][0]).toBe "1111\n"
          expect(stderrHandler.argsForCall[1][0]).toBe "2222\n"

      describe "when the `bufferLines` option is true ", ->
        [simulateStdout, simulateStderr] = []

        beforeEach ->
          spyOn($native, 'exec')
          ChildProcess.exec("print_the_things", bufferLines: true, stdout: stdoutHandler, stderr: stderrHandler)
          { stdout, stderr } = $native.exec.argsForCall[0][1]
          simulateStdout = stdout
          simulateStderr = stderr

        it "only triggers stdout callbacks with complete lines", ->
          simulateStdout """
            I am a full line
            I am part of """

          expect(stdoutHandler).toHaveBeenCalledWith("I am a full line\n")
          stdoutHandler.reset()

          simulateStdout """
            a line
            I am another full line\n
          """

          expect(stdoutHandler).toHaveBeenCalledWith """
            I am part of a line
            I am another full line\n
          """

        it "only triggers stderr callbacks with complete lines", ->
          simulateStderr """
            I am a full line
            I am part of """

          expect(stderrHandler).toHaveBeenCalledWith("I am a full line\n")
          stdoutHandler.reset()

          simulateStderr """
            a line
            I am another full line\n
          """

          expect(stderrHandler).toHaveBeenCalledWith """
            I am part of a line
            I am another full line\n
          """

    describe "when the command fails", ->
      it "executes the callback with error set to the exit status", ->
        waitsForPromise ->
          cmd = "exit 2"
          ChildProcess.exec(cmd).fail (error) ->
            expect(error.exitStatus).toBe 2
