fs = require 'fs'
Buffer = require 'buffer'
_ = require 'underscore'
EventEmitter = require 'event-emitter'
Directory = require 'directory'

module.exports =
class Project
  path: null
  rootDirectory: null
  buffers: null

  constructor: (path) ->
    @setPath(path)
    @buffers = []

  getPath: ->
    @path

  setPath: (path) ->
    @rootDirectory.off() if @rootDirectory

    if path?
      @path = if fs.isDirectory(path) then path else fs.directory(path)
      @rootDirectory = new Directory(@path)
    else
      @path = null
      @rootDirectory = null

  getRootDirectory: ->
    @rootDirectory

  getFilePaths: ->
    projectPath = @path
    fs.async.listTree(@path).pipe (paths) ->
      path.replace(projectPath, "") for path in paths when fs.isFile(path)

  open: (filePath) ->
    if filePath?
      filePath = @resolve(filePath)
      @bufferWithPath(filePath) ? @buildBuffer(filePath)
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

  relativize: (fullPath) ->
    fullPath.replace(@path, "").replace(/^\//, '')

  bufferWithId: (id) ->
    return buffer for buffer in @buffers when buffer.id == id

  bufferWithPath: (path) ->
    return buffer for buffer in @buffers when buffer.path == path

_.extend Project.prototype, EventEmitter
