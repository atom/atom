fs = require 'fs'

module.exports =
class File
  constructor: (@path) ->

  getName: ->
    fs.base(@path)
