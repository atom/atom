{Model} = require 'telepath'
Focusable = require './focusable'
Pane = require './pane'

module.exports =
class PaneContainer extends Model
  Focusable.includeInto(this)

  @property 'children', -> [new Pane(container: this)]
  @relatesToOne 'root', -> @children

  attached: ->
    @root.focusManager = @focusManager
