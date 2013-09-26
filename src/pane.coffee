{Model} = require 'telepath'

PaneAxis = require './pane-axis'

module.exports =
class Pane extends Model
  @resolve 'allComponents'

  @properties
    parentId: null

  @hasMany 'items'

  splitRight: (items...) ->
    @split('after', 'horizontal', items)

  split: (side, orientation, items) ->
    axis = new PaneAxis({@parentId, orientation})
    axis = @allComponents.insertBefore(this, axis)
    @parentId = axis.id
    newPane = new Pane({parentId: axis.id, items})
    @allComponents.insertAfter(this, newPane)
