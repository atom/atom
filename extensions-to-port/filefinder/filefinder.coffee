Extension = require 'extension'
FileFinderPane = require 'filefinder/filefinderpane'

module.exports =
class Filefinder extends Extension
  keymap: ->
    'Command-T': => @pane.toggle()
    # really wish i could put up/down keyboad shortcuts here
    # and have them activated when the filefinder is open

  load: ->
    @pane = new FileFinderPane @window, @
