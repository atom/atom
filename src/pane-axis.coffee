{Model} = require 'telepath'

module.exports =
class PaneAxis extends Model
  @resolve 'allComponents'
  @properties 'parentId', 'orientation'

  @relatesToMany 'children', -> @allComponents.where(parentId: @id)

  @condition
    when: -> @children.$length.becomesLessThan(2)
    call: 'reparentLastChild'

  @condition
    when: -> @children.$length.becomesLessThan(1)
    call: 'destroy'

  reparentLastChild: ->
    @children.getLast().parentId = @parentId
