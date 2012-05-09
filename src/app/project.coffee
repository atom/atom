fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

Buffer = require 'buffer'
EventEmitter = require 'event-emitter'
Directory = require 'directory'

module.exports =
class Project
  rootDirectory: null
  buffers: null

  constructor: (path) ->
    @setPath(path)
    @buffers = []

  getPath: ->
    @rootDirectory?.path

  setPath: (path) ->
    @rootDirectory?.off()

    if path?
      directory = if fs.isDirectory(path) then path else fs.directory(path)
      @rootDirectory = new Directory(directory)
    else
      @rootDirectory = null

    @trigger "path-change"

  getRootDirectory: ->
    @rootDirectory

  getFilePaths: ->
    deferred = $.Deferred()

    filePaths = []
    fs.traverseTree @getPath(), (path, prune) =>
      if @ignorePath(path)
        prune()
      else if fs.isFile(path)
        filePaths.push @relativize(path)

    deferred.resolve filePaths
    deferred

  ignorePath: (path) ->
    fs.base(path).match(/\.DS_Store/) or path.match(/(^|\/)\.git(\/|$)/)

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
    filePath = fs.join(@getPath(), filePath) unless filePath[0] == '/'
    fs.absolute filePath

  relativize: (fullPath) ->
    fullPath.replace(@getPath(), "").replace(/^\//, '')

  bufferWithId: (id) ->
    return buffer for buffer in @buffers when buffer.id == id

  bufferWithPath: (path) ->
    return buffer for buffer in @buffers when buffer.path == path

_.extend Project.prototype, EventEmitter
