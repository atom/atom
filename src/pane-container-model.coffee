{Model} = require 'theorist'

module.exports =
class PaneContainerModel extends Model
  @properties
    root: null

  constructor: ->
    super
    @subscribe @$root, (root) => root?.parent = this

  replaceChild: (oldChild, newChild) ->
    throw new Error("Replacing non-existent child") if oldChild isnt @root
    @root = newChild
