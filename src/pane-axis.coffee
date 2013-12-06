{Model} = require 'telepath'

module.exports =
class PaneAxis extends Model
  @properties
    parent: null
    orientation: null
    children: []

  @relatesToMany 'panes', -> @children.selectMany 'panes'

  @condition
    when: -> @children.$length.becomesLessThan 2
    call: 'reparentLastChild'

  reparentLastChild: ->
    lastChild = @children.getLast()
    lastChild.parent = @parent
    @parent.children.replace(this, lastChild)
