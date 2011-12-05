Extension = require 'extension'
Pane = require 'blank-extension/pane'

module.exports =
class BlankExtension extends Extension
  constructor: ->
    atom.on 'project:open', @startup

  startup: =>
    #@pane = new Pane this
    #@pane.show()
    super

  shutdown: ->
    #@pane.remove()
    super
