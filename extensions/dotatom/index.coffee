fs = require 'fs'

module.exports =
class Dotatom
  constructor: ->
    try
      require "~/.atom"
    catch e
      console.log 'No ~/.atom module found.'

    atom.settings.load "~/.atom/settings.coffee"
    atom.keybinder.load "~/.atom/key-bindings.coffee"