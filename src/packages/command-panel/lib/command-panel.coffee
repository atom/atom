CommandPanelView = require './command-panel-view'

module.exports =
  commandPanelView: null

  activate: (rootView, @state) ->
    @commandPanelView = new CommandPanelView(@state)

  deactivate: ->
    @commandPanelView?.destroy()
    @commandPanelView = null

  serialize: ->
    if @commandPanelView?
      @commandPanelView.serialize()
    else
      @state
