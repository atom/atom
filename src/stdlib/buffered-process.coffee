ChildProcess = require 'child_process'

module.exports =
class BufferedProcess
  constructor: ({command, args, options, stdout, stderr, exit}={}) ->
    process = ChildProcess.spawn(command, args, options)

    stdoutClosed = true
    stderrClosed = true
    processExited = true
    exitCode = 0
    triggerExitCallback = ->
      if stdoutClosed and stderrClosed and processExited
        exit?(exitCode)

    if stdout
      stdoutClosed = false
      @bufferStream process.stdout, stdout, ->
        stdoutClosed = true
        triggerExitCallback()

    if stderr
      stderrClosed = false
      @bufferStream process.stderr, stderr, ->
        stderrClosed = true
        triggerExitCallback()

    if exit
      processExited = false
      process.on 'exit', (code) ->
        exitCode = code
        processExited = true
        triggerExitCallback()

  bufferStream: (stream, onLines, onDone) ->
    stream.setEncoding('utf8')
    buffered = ''

    stream.on 'data', (data) ->
      buffered += data
      lastNewlineIndex = buffered.lastIndexOf('\n')
      if lastNewlineIndex isnt -1
        onLines(buffered.substring(0, lastNewlineIndex + 1))
        buffered = buffered.substring(lastNewlineIndex + 1)

    stream.on 'close', =>
      onLines(buffered) if buffered.length > 0
      onDone()
