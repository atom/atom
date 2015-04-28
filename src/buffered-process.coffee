_ = require 'underscore-plus'
ChildProcess = require 'child_process'
{Emitter} = require 'event-kit'
path = require 'path'

# Extended: A wrapper which provides standard error/output line buffering for
# Node's ChildProcess.
#
# ## Examples
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
  ###
  Section: Construction
  ###

  # Public: Runs the given command by spawning a new child process.
  #
  # * `options` An {Object} with the following keys:
  #   * `command` The {String} command to execute.
  #   * `args` The {Array} of arguments to pass to the command (optional).
  #   * `options` {Object} (optional) The options {Object} to pass to Node's
  #     `ChildProcess.spawn` method.
  #   * `stdout` {Function} (optional) The callback that receives a single
  #     argument which contains the standard output from the command. The
  #     callback is called as data is received but it's buffered to ensure only
  #     complete lines are passed until the source stream closes. After the
  #     source stream has closed all remaining data is sent in a final call.
  #     * `data` {String}
  #   * `stderr` {Function} (optional) The callback that receives a single
  #     argument which contains the standard error output from the command. The
  #     callback is called as data is received but it's buffered to ensure only
  #     complete lines are passed until the source stream closes. After the
  #     source stream has closed all remaining data is sent in a final call.
  #     * `data` {String}
  #   * `exit` {Function} (optional) The callback which receives a single
  #     argument containing the exit status.
  #     * `code` {Number}
  constructor: ({command, args, options, stdout, stderr, exit}={}) ->
    @emitter = new Emitter
    options ?= {}
    # Related to joyent/node#2318
    if process.platform is 'win32'
      # Quote all arguments and escapes inner quotes
      if args?
        cmdArgs = args.filter (arg) -> arg?
        cmdArgs = cmdArgs.map (arg) =>
          if @isExplorerCommand(command) and /^\/[a-zA-Z]+,.*$/.test(arg)
            # Don't wrap /root,C:\folder style arguments to explorer calls in
            # quotes since they will not be interpreted correctly if they are
            arg
          else
            "\"#{arg.toString().replace(/"/g, '\\"')}\""
      else
        cmdArgs = []
      if /\s/.test(command)
        cmdArgs.unshift("\"#{command}\"")
      else
        cmdArgs.unshift(command)
      cmdArgs = ['/s', '/c', "\"#{cmdArgs.join(' ')}\""]
      cmdOptions = _.clone(options)
      cmdOptions.windowsVerbatimArguments = true
      @process = @spawn(@getCmdPath(), cmdArgs, cmdOptions)
    else
      @process = @spawn(command, args, options)

    @killed = false
    @handeEvents(stdout, stderr, exit) if @process?

  ###
  Section: Event Subscription
  ###

  # Public: Will call your callback when an error will be raised by the process.
  # Usually this is due to the command not being available or not on the PATH.
  # You can call `handle()` on the object passed to your callback to indicate
  # that you have handled this error.
  #
  # * `callback` {Function} callback
  #   * `errorObject` {Object}
  #     * `error` {Object} the error object
  #     * `handle` {Function} call this to indicate you have handled the error.
  #       The error will not be thrown if this function is called.
  #
  # Returns a {Disposable}
  onWillThrowError: (callback) ->
    @emitter.on 'will-throw-error', callback

  ###
  Section: Helper Methods
  ###

  # Helper method to pass data line by line.
  #
  # * `stream` The Stream to read from.
  # * `onLines` The callback to call with each line of data.
  # * `onDone` The callback to call when the stream has closed.
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
  killOnWindows: ->
    return unless @process?

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
    wmicProcess.on 'error', -> # ignore errors
    output = ''
    wmicProcess.stdout.on 'data', (data) -> output += data
    wmicProcess.stdout.on 'close', =>
      pidsToKill = output.split(/\s+/)
                    .filter (pid) -> /^\d+$/.test(pid)
                    .map (pid) -> parseInt(pid)
                    .filter (pid) -> pid isnt parentPid and 0 < pid < Infinity

      for pid in pidsToKill
        try
          process.kill(pid)
      @killProcess()

  killProcess: ->
    @process?.kill()
    @process = null

  isExplorerCommand: (command) ->
    if command is 'explorer.exe' or command is 'explorer'
      true
    else if process.env.SystemRoot
      command is path.join(process.env.SystemRoot, 'explorer.exe') or command is path.join(process.env.SystemRoot, 'explorer')
    else
      false

  getCmdPath: ->
    if process.env.comspec
      process.env.comspec
    else if process.env.SystemRoot
      path.join(process.env.SystemRoot, 'System32', 'cmd.exe')
    else
      'cmd.exe'

  # Public: Terminate the process.
  kill: ->
    return if @killed

    @killed = true
    if process.platform is 'win32'
      @killOnWindows()
    else
      @killProcess()

    undefined

  spawn: (command, args, options) ->
    try
      process = ChildProcess.spawn(command, args, options)
    catch spawnError
      process.nextTick => @handleError(spawnError)
    process

  handleEvents: (stdout, stderr, exit) ->
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

    @process.on 'error', (error) => @handleError(error)
    return

  handleError: (error) ->
    handled = false
    handle = -> handled = true

    @emitter.emit 'will-throw-error', {error, handle}

    if error.code is 'ENOENT' and error.syscall.indexOf('spawn') is 0
      error = new Error("Failed to spawn command `#{command}`. Make sure `#{command}` is installed and on your PATH", error.path)
      error.name = 'BufferedProcessError'

    throw error unless handled
