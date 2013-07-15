ChildProcess = require 'child_process'
path = require 'path'
_ = require 'underscore'

module.exports =
class BufferedProcess
  process: null
  killed: false

  constructor: ({command, args, options, stdout, stderr, exit}={}) ->
    options ?= {}
    @addNodeDirectoryToPath(options)
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

  addNodeDirectoryToPath: (options) ->
    options.env ?= process.env
    pathSegments = []
    nodeDirectoryPath = path.resolve(process.execPath, '..', '..', '..', '..', '..', 'Resources')
    pathSegments.push(nodeDirectoryPath)
    pathSegments.push(options.env.PATH) if options.env.PATH
    options.env = _.extend({}, options.env, PATH: pathSegments.join(path.delimiter))

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

  kill: ->
    @killed = true
    @process.kill()
    @process = null
