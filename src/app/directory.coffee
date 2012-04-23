fs = require 'fs'
File = require 'file'

module.exports =
class Directory
  constructor: (@path) ->

  getName: ->
    fs.base(@path)

  getEntries: ->
    fs.list(@path).map (path) ->
      if fs.isDirectory(path)
        new Directory(path)
      else
        new File(path)


