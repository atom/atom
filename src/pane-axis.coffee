{Model} = require 'telepath'

module.exports =
class PaneAxis extends Model
  @resolve 'allComponents'
  @properties 'parentId', 'orientation'

  @relatesToMany 'children', -> @allComponents.where(parentId: @id)
