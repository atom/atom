_ = require 'underscore'
$ = require 'jquery'
fs = require 'fs'

Extension = require 'extension'
Modal = require 'modal'

module.exports =
class Showkeybindings extends Extension
  constructor: ->
    atom.keybinder.load require.resolve "showkeybindings/key-bindings.coffee"
    atom.on 'project:open', @startup

  startup: (@project) =>
    html = '<h1>Keybindings</h1>'
    for name, bindings of atom.keybinder.keymaps
      html += "<h3>#{name}</h3>"
      html += "<ul>"
      for binding, method of bindings
        html += """
        <li>#{atom.keybinder.bindingFromAscii(binding)} - #{method}</li>
        """
      html += "</ul>"
    @pane = new Modal html

  toggle: ->
    @pane?.toggle()
