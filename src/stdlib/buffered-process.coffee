ChildProcess = nodeRequire 'child_process'

module.exports =
class BufferedProcess
  constructor: (options={}) ->
    process = ChildProcess.spawn(options.command, options.args)

    stdoutClosed = true
    stderrClosed = true
    processExited = true
    exitCode = 0
    triggerExitCallback = ->
      if stdoutClosed and stderrClosed and processExited
        options.exit?(exitCode)

    if options.stdout
      stdoutClosed = false
      @bufferStream process.stdout, options.stdout, ->
        stdoutClosed = true
        triggerExitCallback()

    if options.stderr
      stderrClosed = false
      @bufferStream process.stderr, options.stderr, ->
        stderrClosed = true
        triggerExitCallback()

    if options.exit
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
