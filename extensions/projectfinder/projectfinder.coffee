_ = require 'underscore'
fs = require 'fs'

Extension = require 'extension'
ModalSelector = require 'modal-selector'

module.exports =
class Projectfinder extends Extension
  settings:
    root: "~/Code"

  constructor: ->
    atom.keybinder.load require.resolve "projectfinder/key-bindings.coffee"
    atom.on 'project:open', @startup

  startup: (@project) =>
    @pane = new ModalSelector =>
      _.compact _.map (fs.list @settings.root), (url) =>
        return if fs.isFile url
        name = url.replace "#{fs.absolute @settings.root}/", ''
        { name, url }

  toggle: ->
    @pane?.toggle()
