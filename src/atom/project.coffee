fs = require 'fs'
Buffer = require 'buffer'

module.exports =

class Project
  constructor: (@url) ->

  getFilePaths: ->
    fs.async.listFiles(@url, true)

  open: (filePath) ->
    new Buffer(@resolve(filePath))

  resolve: (filePath) ->
    if filePath[0] == '/'
      filePath
    else
      fs.join(@url, filePath)

