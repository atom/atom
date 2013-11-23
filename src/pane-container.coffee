{Model} = require 'telepath'
Pane = require './pane'

module.exports =
class PaneContainer extends Model
  @property 'children', -> [new Pane(container: this)]
  @relatesToOne 'root', -> @children
