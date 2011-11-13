_ = require 'underscore'

Extension = require 'extension'
ModalSelector = require 'modal-selector'

module.exports =
class Filefinder extends Extension
  constructor: ->
    atom.keybinder.load require.resolve "filefinder/key-bindings.coffee"
    atom.on 'project:open', @startup

  startup: (@project) =>
    @pane = new ModalSelector @project.allURLs()

  toggle: ->
    @pane?.toggle()
