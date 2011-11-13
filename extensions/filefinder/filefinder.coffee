_ = require 'underscore'
fs = require 'fs'

Extension = require 'extension'
ModalSelector = require 'modal-selector'

module.exports =
class Filefinder extends Extension
  constructor: ->
    atom.keybinder.load require.resolve "filefinder/key-bindings.coffee"
    atom.on 'project:open', @startup

  startup: (@project) =>
    @pane = new ModalSelector _.reject @project.allURLs(), ({url}) ->
      fs.isDirectory url

  toggle: ->
    @pane?.toggle()
