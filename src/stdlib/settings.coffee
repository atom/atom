fs = require 'fs'

module.exports =
class Settings
  constructor: ->
    atom.on 'window:load', ->
      if fs.isFile "~/.atomicity/settings.coffee"
        require "~/.atomicity/settings.coffee"
