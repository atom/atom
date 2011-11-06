Extension = require 'extension'
KeyBinder = require 'key-binder'
Event = require 'event'
FilefinderPane = require 'filefinder/filefinder-pane'

module.exports =
class Filefinder extends Extension
  constructor: ->
    KeyBinder.register "filefinder", @
    KeyBinder.load require.resolve "filefinder/key-bindings.coffee"

    @pane = new FilefinderPane @

  toggle: ->
    @pane.toggle()