TerminalView  = require 'terminal/lib/terminal-view'
_ = require 'underscore'

module.exports =
  activate: (state) ->
    rootView.command 'terminal:create-split-down', =>
      activePane = rootView.getActivePane()
      view = @createView()
      activePane.splitDown(view)

  createView: () ->
    new TerminalView

  serialize: ->
    true
