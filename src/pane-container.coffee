{Model} = require 'telepath'

Pane = require './pane'

module.exports =
class PaneContainer extends Model
  @properties
    allComponents: []
    allItems: []

  @relatesToMany 'panes', -> @allComponents.where(modelClassName: 'Pane')
  @relatesToOne 'root', -> @allComponents.where(parentId: null)

  createPane: (items...) ->
    @allComponents.push(new Pane({items}))
