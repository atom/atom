Extension = require 'extension'
FilefinderPane = require 'filefinder/filefinder-pane'

module.exports =
class Filefinder extends Extension
  constructor: ->
    atom.keybinder.register "filefinder", @
    atom.keybinder.load require.resolve "filefinder/key-bindings.coffee"

    @pane = new FilefinderPane @

  toggle: ->
    @pane.toggle()