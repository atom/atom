Extension = require 'extension'
FilefinderPane = require 'filefinder/filefinder-pane'

module.exports =
class Filefinder extends Extension
  constructor: ->
    atom.keybinder.load require.resolve "filefinder/key-bindings.coffee"
    atom.on 'project:load', @startup

  startup: =>
    @pane = new FilefinderPane this

  toggle: ->
    @pane?.toggle()