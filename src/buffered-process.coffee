ChildProcess = require 'child_process'
path = require 'path'
_ = require 'underscore'

# Private: A wrapper which provides buffering for ChildProcess.
module.exports =
class BufferedProcess
  process: null
  killed: false

  # Executes the given command.
  #
  # * options
  #    + command:
  #      The command to execute.
  #    + args:
  #      The arguments for the given command.
  #    + options:
  #      The options to pass to ChildProcess.
  #    + stdout:
  #      The callback to receive stdout data.
  #    + stderr:
  #      The callback to receive stderr data.
  #    + exit:
  #      The callback to receive exit status.
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
