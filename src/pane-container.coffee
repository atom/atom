{Model} = require 'telepath'
Focusable = require './focusable'
Pane = require './pane'

# Private: Manages the list of panes within a {WorkspaceView}
module.exports =
class PaneContainer extends Model
  Focusable.includeInto(this)

  @properties
    children: -> [new Pane(container: this, parent: this)]
    activePane: null

  @relatesToOne 'root', -> @children

  attached: ->
    @activePane ?= @root
    @root.setFocusManager?(@focusManager)
