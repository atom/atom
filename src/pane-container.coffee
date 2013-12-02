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
  @relatesToMany 'panes', -> @children.selectMany 'panes'
  @relatesToMany 'paneItems', -> @panes.selectMany 'items'

  @behavior 'activePaneItem', -> @$activePane.flatMapLatest (pane) -> pane.$activeItem

  attached: ->
    @activePane ?= @root
    @root.setFocusManager?(@focusManager)

  # Deprecated
  # Deprecated: Use ::activePane property directly
  getActivePane: -> @activePane

  # Deprecated: Use ::activePaneItem property directly
  getActivePaneItem: -> @activePaneItem

  # Public: Returns the first pane with an item for the given uri
  paneForUri: (uri) ->
    @panes.find (pane) -> pane.itemForUri(uri)?
