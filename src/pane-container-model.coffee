{Model} = require 'theorist'
Serializable = require 'serializable'

module.exports =
class PaneContainerModel extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @properties
    root: null

  constructor: ->
    super
    @subscribe @$root, (root) => root?.parent = this

  deserializeParams: (params) ->
    params.root = atom.deserializers.deserialize(params.root)
    params

  serializeParams: (params) ->
    root: @root?.serialize()

  replaceChild: (oldChild, newChild) ->
    throw new Error("Replacing non-existent child") if oldChild isnt @root
    @root = newChild
