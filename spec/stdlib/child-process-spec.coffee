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
        standardOutput = ''
        errorOutput = ''
        options =
          stdout: (data) ->
            standardOutput += data
          stderr: (data) ->
            errorOutput += data

        ChildProcess.exec(cmd, options).done ->
          expect(standardOutput).toBe 'good\n'
          expect(errorOutput).toBe 'bad\n'

    describe "when options are given", ->
      it "calls the options.stdout callback when new data is received on stdout", ->
        cmd = "echo 'first' && sleep .1 && echo 'second' && sleep .1 && echo 'third'"
        ChildProcess.exec(cmd, stdout: stdoutHandler)

        waitsFor ->
          stdoutHandler.callCount > 2

        runs ->
          expect(stdoutHandler.argsForCall[0][0]).toBe "first\n"
          expect(stdoutHandler.argsForCall[1][0]).toBe "second\n"
          expect(stdoutHandler.argsForCall[2][0]).toBe "third\n"

      it "calls the options.stderr callback when new data is received on stderr", ->
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
        waitsForPromise shouldReject: true, ->
          cmd = "echo 'bad' >&2 && exit 2"
          errorOutput = ''
          options =
            stderr: (data) ->
              errorOutput += data
          ChildProcess.exec(cmd, options).fail (error) ->
            expect(error.exitStatus).toBe 2
            expect(errorOutput).toBe "bad\n"

    describe "when a command returns a large amount of data (over 10k)", ->
      originalTimeout = null
      beforeEach ->
        originalTimeout = jasmine.getEnv().defaultTimeoutInterval
        jasmine.getEnv().defaultTimeoutInterval = 1000

      afterEach ->
        jasmine.getEnv().defaultTimeoutInterval = originalTimeout

      it "does not block indefinitally on stdout or stderr callbacks (regression)", ->
        output = []

        waitsForPromise ->
          cmd = "for i in {1..20000}; do echo $RANDOM; done"
          options =
            stdout: (data) -> output.push(data)
            stderr: (data) ->

          ChildProcess.exec(cmd, options)

        runs ->
          expect(output.length).toBeGreaterThan 1

    describe "when the cwd option is set", ->
      it "runs the task from the specified current working directory", ->
        output = []

        waitsForPromise ->
          options =
            cwd: fixturesProject.getPath()
            stdout: (data) -> output.push(data)
            stderr: (data) ->

          ChildProcess.exec("pwd", options)

        runs ->
          expect(output.join('')).toBe "#{fixturesProject.getPath()}\n"

      describe "when the interactive option is set", ->
        it "runs the task in a pty session", ->
          output = []

          waitsForPromise ->
            options =
              interactive: true
              stdout: (data) -> output.push(data)

            p = ChildProcess.exec("/bin/bash", options)
            p.write("echo $SHELL && exit\n", true)
            p

          runs ->
            expect(output.join('')).toContain("bash")

      describe "write to stdin", ->
        it "returns a function for writing", ->
          promise = ChildProcess.exec("pwd")
          expect(typeof promise.write).toBe("function")
        it "writes data to the process", ->
          output = []

          waitsForPromise ->
            options =
              stdout: (data) -> output.push(data)
              stderr: (data) ->

            p = ChildProcess.exec("cat", options)
            p.write("hello, world\n", true)
            p
          runs ->
            expect(output.join('')).toBe("hello, world\n")
