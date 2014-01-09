{Model, Sequence} = require 'theorist'
Serializable = require 'serializable'

PaneRow = null
PaneColumn = null

module.exports =
class PaneAxisModel extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  constructor: ({@orientation, children}) ->
    @children = Sequence.fromArray(children ? [])

    @children.onEach (child) =>
      child.parent = this
      @subscribe child, 'destroyed', => @removeChild(child)

    @children.onRemoval (child) => @unsubscribe(child)

    @when @children.$length.becomesLessThan(2), 'reparentLastChild'
    @when @children.$length.becomesLessThan(1), 'destroy'

  deserializeParams: (params) ->
    params.children = params.children.map (childState) -> atom.deserializers.deserialize(childState)
    params

  serializeParams: ->
    children: @children.map (child) -> child.serialize()

  getViewClass: ->
    if @orientation is 'vertical'
      PaneColumn ?= require './pane-column'
    else
      PaneRow ?= require './pane-row'

  addChild: (child, index=@children.length) ->
    @children.splice(index, 0, child)

  removeChild: (child) ->
    index = @children.indexOf(child)
    throw new Error("Removing non-existent child") if index is -1
    @children.splice(index, 1)

  replaceChild: (oldChild, newChild) ->
    index = @children.indexOf(oldChild)
    throw new Error("Replacing non-existent child") if index is -1
    @children.splice(index, 1, newChild)

  insertChildBefore: (currentChild, newChild) ->
    index = @children.indexOf(currentChild)
    @children.splice(index, 0, newChild)

  insertChildAfter: (currentChild, newChild) ->
    index = @children.indexOf(currentChild)
    @children.splice(index + 1, 0, newChild)

  reparentLastChild: ->
    @parent.replaceChild(this, @children[0])
