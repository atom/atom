fs = require 'fs'
Buffer = require 'buffer'
_ = require 'underscore'
EventEmitter = require 'event-emitter'

module.exports =
class Project
  buffers: null

  constructor: (@path) ->
    @buffers = {}

  getFilePaths: ->
    projectPath = @path
    fs.async.listTree(@path).pipe (paths) ->
      path.replace(projectPath, "") for path in paths when fs.isFile(path)

  open: (filePath) ->
    if filePath?
      filePath = @resolve(filePath)
      buffer = @buffers[filePath]
      unless buffer
        @buffers[filePath] = buffer = new Buffer(filePath)
        @trigger 'new-buffer', buffer
    else
      buffer = new Buffer
      @trigger 'new-buffer', buffer
    buffer

  resolve: (filePath) ->
    filePath = fs.join(@path, filePath) unless filePath[0] == '/'
    fs.absolute filePath

_.extend Project.prototype, EventEmitter
