fs = require 'fs'

module.exports =

class Project
  constructor: (@url) ->

  getFilePaths: ->
    fs.async.listFiles(@url, true)

