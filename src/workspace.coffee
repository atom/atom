{Model} = require 'telepath'

PaneContainer = require './pane-container'

module.exports =
class Workspace extends Model
  @properties
    project: null
    panes: -> new PaneContainer

  @delegates 'activePane', 'activePaneItem', to: 'panes'

  openSync: (uri, options={}) ->
    editor = @project.openSync(uri)
    @activePane.setActiveItem(editor)
    @activePane.focused = true if options.changeFocus ? true
    editor
