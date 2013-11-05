{Model} = require 'telepath'
Pane = require './pane'

module.exports =
class PaneContainer extends Model
  @property 'root'

  createPane: (items...) ->
    @root = new Pane({items})
