{Model} = require 'telepath'

PaneContainer = require './pane-container'

module.exports =
class Workspace extends Model
  @properties
    project: null
    panes: -> new PaneContainer

  @delegates 'activePane', 'activePaneItem', to: 'panes'

  openSync: (uri, {changeFocus, initialLine, split}={}) ->
    uri = @project.relativize(uri)
    editor = @activePane.itemForUri(uri) if uri?
    editor ?= @project.openSync(uri, {initialLine})
    @activePane.setActiveItem(editor)
    @activePane.focused = true if changeFocus ? true
    editor
