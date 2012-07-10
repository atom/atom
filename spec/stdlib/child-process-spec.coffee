ChildProcess = require 'child-process'

fdescribe 'Child Processes', ->
  describe ".exec(command, options)", ->
    it "returns a promise that resolves to stdout and stderr", ->
      waitsForPromise ->
        cmd = "echo 'good' && echo 'bad' >&2"
        ChildProcess.exec(cmd).done (stdout, stderr) ->
          expect(stdout).toBe 'good\n'
          expect(stderr).toBe 'bad\n'

    describe "when `options` contains a stdout function", ->
      it "calls the stdout function when new data is received", ->
        stderrHandler = jasmine.createSpy "stderrHandler"

        cmd = "echo '1111' >&2 && sleep .1 && echo '2222' >&2"
        ChildProcess.exec(cmd, stderr: stderrHandler)

        waitsFor ->
          stderrHandler.callCount > 1

        runs ->
          expect(stderrHandler.argsForCall[0][0]).toBe "1111\n"
          expect(stderrHandler.argsForCall[1][0]).toBe "2222\n"

      it "calls the stderr function when new data is received", ->
        stdoutHandler = jasmine.createSpy "stdoutHandler"

        cmd = "echo 'first' && sleep .1 && echo 'second' && sleep .1 && echo 'third'"
        ChildProcess.exec(cmd, stdout: stdoutHandler)

        waitsFor ->
          stdoutHandler.callCount > 2

        runs ->
          expect(stdoutHandler.argsForCall[0][0]).toBe "first\n"
          expect(stdoutHandler.argsForCall[1][0]).toBe "second\n"
          expect(stdoutHandler.argsForCall[2][0]).toBe "third\n"

    describe "when the command fails", ->
      it "executes the callback with error set to the exit status", ->
        waitsForPromise ->
          cmd = "exit 2"
          ChildProcess.exec(cmd).fail (error) ->
            expect(error.exitStatus).toBe 2


