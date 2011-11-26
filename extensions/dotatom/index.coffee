fs = require 'fs'

module.exports = 
class Dotatom
  constructor: ->
    try
      require "~/.atomicity"
    catch e
      console.log 'No ~/.atomicity module found.'
      
    atom.settings.load "~/.atomicity/settings.coffee"
    atom.keybinder.load "~/.atomicity/key-bindings.coffee"