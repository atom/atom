fs = require 'fs'
Buffer = require 'buffer'

module.exports =

class Project
  buffers: null

  constructor: (@url) ->
    @buffers = {}

  getFilePaths: ->
    projectUrl = @url
    fs.async.listTree(@url).pipe (urls) ->
      url.replace(projectUrl, "") for url in urls when fs.isFile(url)

  open: (filePath) ->
    filePath = @resolve filePath
    @buffers[filePath] ?= new Buffer(filePath)

  resolve: (filePath) ->
    filePath = fs.join(@url, filePath) unless filePath[0] == '/'
    fs.absolute filePath

