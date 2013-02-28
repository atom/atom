_ = require 'underscore'

module.exports =
  terminalView: null

  activate: (state) ->
    rootView.command 'terminal:toggle-terminal', =>
      if @terminalView?
        @deactivate()
      else
        @createView().attach()

  deactivate: ->
    @terminalView.detach() if @terminalView?
    @terminalView = null

  serialize: ->
    true

  createView:  ->
    unless @terminalView
      TerminalView  = require 'terminal/lib/terminal-view'
      @terminalView = new TerminalView()
    @terminalView
