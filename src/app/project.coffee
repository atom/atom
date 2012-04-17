fs = require 'fs'
Buffer = require 'buffer'

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
    filePath = @resolve filePath
    @buffers[filePath] ?= new Buffer(filePath)

  resolve: (filePath) ->
    filePath = fs.join(@path, filePath) unless filePath[0] == '/'
    fs.absolute filePath

  relativize: (path) ->
    path.replace(@path, '')
