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
  @relatesToOne 'focusedPane', -> @panes.where(hasFocus: true)

  @behavior 'activePaneItem', -> @$activePane.flatMapLatest (pane) -> pane.$activeItem

  attached: ->
    @activePane ?= @root
    @root.setFocusManager?(@focusManager)

  # Deprecated: Use ::panes property directly
  getPanes: -> @panes

  # Deprecated: Use ::activePane property directly
  getActivePane: -> @activePane

  # Deprecated: Use ::activePaneItem property directly
  getActivePaneItem: -> @activePaneItem

  # Public: Returns the first pane with an item for the given uri
  paneForUri: (uri) ->
    @panes.find (pane) -> pane.itemForUri(uri)?

  focusNextPane: ->
    nextIndex = (@getFocusedPaneIndex() + 1) % @panes.length
    @panes.get(nextIndex).focused = true

  focusPreviousPane: ->
    previousIndex = (@getFocusedPaneIndex() - 1)
    previousIndex = @panes.length - 1 if previousIndex < 0
    @panes.get(previousIndex).focused = true

  getFocusedPaneIndex: ->
    @panes.indexOf(@focusedPane)
