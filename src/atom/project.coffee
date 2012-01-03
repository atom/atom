fs = require 'fs'

module.exports =

class Project
  constructor: (@url) ->

  list: ->
    fs.async.list(@url, true)

