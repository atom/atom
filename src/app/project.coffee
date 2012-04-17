fs = require 'fs'
Buffer = require 'buffer'
_ = require 'underscore'
EventEmitter = require 'event-emitter'

module.exports =
class Project
  buffersByPath: null
  buffers: null

  constructor: (@path) ->
    @buffersByPath = {}
    @buffers = []

  getFilePaths: ->
    projectPath = @path
    fs.async.listTree(@path).pipe (paths) ->
      path.replace(projectPath, "") for path in paths when fs.isFile(path)

  open: (filePath) ->
    if filePath?
      filePath = @resolve(filePath)
      @buffersByPath[filePath] ?= @buildBuffer(filePath)
    else
      @buildBuffer()

  buildBuffer: (filePath) ->
    buffer = new Buffer(filePath)
    @buffers.push(buffer)
    @trigger 'new-buffer', buffer
    buffer

  resolve: (filePath) ->
    filePath = fs.join(@path, filePath) unless filePath[0] == '/'
    fs.absolute filePath

_.extend Project.prototype, EventEmitter
