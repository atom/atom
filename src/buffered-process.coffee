_ = require 'underscore-plus'
ChildProcess = require 'child_process'

# Public: A wrapper which provides standard error/output line buffering for
# Node's ChildProcess.
#
# ## Requiring in packages
#
# ```coffee
# {BufferedProcess} = require 'atom'
#
# command = 'ps'
# args = ['-ef']
# stdout = (output) -> console.log(output)
# exit = (code) -> console.log("ps -ef exited with #{code}")
# process = new BufferedProcess({command, args, stdout, exit})
# ```
module.exports =
class BufferedProcess
  # Public: Runs the given command by spawning a new child process.
  #
  # options - An {Object} with the following keys:
  #   :command - The {String} command to execute.
  #   :args - The {Array} of arguments to pass to the command (optional).
  #   :options - The options {Object} to pass to Node's `ChildProcess.spawn`
  #              method (optional).
  #   :stdout - The callback {Function} that receives a single argument which
  #             contains the standard output from the command. The callback is
  #             called as data is received but it's buffered to ensure only
  #             complete lines are passed until the source stream closes. After
  #             the source stream has closed all remaining data is sent in a
  #             final call (optional).
  #   :stderr - The callback {Function} that receives a single argument which
  #             contains the standard error output from the command. The
  #             callback is called as data is received but it's buffered to
  #             ensure only complete lines are passed until the source stream
  #             closes. After the source stream has closed all remaining data
  #             is sent in a final call (optional).
  #   :exit - The callback {Function} which receives a single argument
  #           containing the exit status (optional).
  constructor: ({command, args, options, stdout, stderr, exit}={}) ->
    options ?= {}
    # Quick hack. Killing @process will only kill cmd.exe, and not the child
    # process and will just orphan it. Does not escape ^ (cmd's escape symbol).
    # Related to joyent/node#2318
    if process.platform is "win32"
      # Quote all arguments and escapes inner quotes
      if args?
        cmdArgs = args.map (arg) ->
          if command in ['explorer.exe', 'explorer'] and /^\/[a-zA-Z]+,.*$/.test(arg)
            # Don't wrap /root,C:\folder style arguments to explorer calls in
            # quotes since they will not be interpreted correctly if they are
            arg
          else
            "\"#{arg.replace(/"/g, '\\"')}\""
      else
        cmdArgs = []
      if /\s/.test(command)
        cmdArgs.unshift("\"#{command}\"")
      else
        cmdArgs.unshift(command)
      cmdArgs = ['/s', '/c', "\"#{cmdArgs.join(' ')}\""]
      cmdOptions = _.clone(options)
      cmdOptions.windowsVerbatimArguments = true
      @process = ChildProcess.spawn(process.env.comspec or 'cmd.exe', cmdArgs, cmdOptions)
    else
      @process = ChildProcess.spawn(command, args, options)
    @killed = false

    stdoutClosed = true
    stderrClosed = true
    processExited = true
    exitCode = 0
    triggerExitCallback = ->
      return if @killed
      if stdoutClosed and stderrClosed and processExited
        exit?(exitCode)

    if stdout
      stdoutClosed = false
      @bufferStream @process.stdout, stdout, ->
        stdoutClosed = true
        triggerExitCallback()

    if stderr
      stderrClosed = false
      @bufferStream @process.stderr, stderr, ->
        stderrClosed = true
        triggerExitCallback()

    if exit
      processExited = false
      @process.on 'exit', (code) ->
        exitCode = code
        processExited = true
        triggerExitCallback()

  # Helper method to pass data line by line.
  #
  # stream - The Stream to read from.
  # onLines - The callback to call with each line of data.
  # onDone - The callback to call when the stream has closed.
  bufferStream: (stream, onLines, onDone) ->
    stream.setEncoding('utf8')
    buffered = ''

    stream.on 'data', (data) =>
      return if @killed
      buffered += data
      lastNewlineIndex = buffered.lastIndexOf('\n')
      if lastNewlineIndex isnt -1
        onLines(buffered.substring(0, lastNewlineIndex + 1))
        buffered = buffered.substring(lastNewlineIndex + 1)

    stream.on 'close', =>
      return if @killed
      onLines(buffered) if buffered.length > 0
      onDone()

  # Kill all child processes of the spawned cmd.exe process on Windows.
  #
  # This is required since killing the cmd.exe does not terminate child
  # processes.
  killAllChildProcessesOnWindows: ->
    parentPid = @process.pid
    cmd = 'wmic'
    args = [
      'process'
      'where'
      "(ParentProcessId=#{parentPid})"
      'get'
      'processid'
    ]

    wmicProcess = ChildProcess.spawn(cmd, args)
    output = ''
    wmicProcess.stdout.on 'data', (data) -> output += data
    wmicProcess.stdout.on 'close', ->
      pidsToKill = output.split('\n')
                    .filter (pid) -> /^\d+$/.test(pid)
                    .map (pid) -> parseInt(pid)
                    .filter (pid) -> not pid is parentPid
      process.kill(pid) for pid in pidsToKill

  # Public: Terminate the process.
  kill: ->
    @killed = true
    @killAllChildProcessesOnWindows() if process.platform is 'win32'
    @process.kill()
    @process = null
