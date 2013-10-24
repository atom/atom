ChildProcess = require 'child_process'

# Public: A wrapper which provides line buffering for Node's ChildProcess.
module.exports =
class BufferedProcess
  process: null
  killed: false

  # Executes the given executable.
  #
  # * options
  #    + command:
  #      The path to the executable to execute.
  #    + args:
  #      The array of arguments to pass to the script (optional).
  #    + options:
  #      The options Object to pass to Node's `ChildProcess.spawn` (optional).
  #    + stdout:
  #      The callback that receives a single argument which contains the
  #      standard output of the script. The callback is called as data is
  #      received but it's buffered to ensure only complete lines are passed
  #      until the source stream closes. After the source stream has closed
  #      all remaining data is sent in a final call (optional).
  #    + stderr:
  #      The callback that receives a single argument which contains the
  #      standard error of the script. The callback is called as data is
  #      received but it's buffered to ensure only complete lines are passed
  #      until the source stream closes. After the source stream has closed
  #      all remaining data is sent in a final call (optional).
  #    + exit:
  #      The callback which receives a single argument containing the exit
  #      status (optional).
  constructor: ({command, args, options, stdout, stderr, exit}={}) ->
    options ?= {}
    @process = ChildProcess.spawn(command, args, options)

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

  # Private: Helper method to pass data line by line.
  #
  # * stream:
  #   The Stream to read from.
  # * onLines:
  #   The callback to call with each line of data.
  # * onDone:
  #   The callback to call when the stream has closed.
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

  # Public: Terminates the process.
  kill: ->
    @killed = true
    @process.kill()
    @process = null
