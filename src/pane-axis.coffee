{Model} = require 'theorist'
{flatten} = require 'underscore-plus'
Serializable = require 'serializable'

PaneRowView = null
PaneColumnView = null

module.exports =
class PaneAxis extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  constructor: ({@container, @orientation, children}) ->
    @children = []
    if children?
      @addChild(child) for child in children

  deserializeParams: (params) ->
    {container} = params
    params.children = params.children.map (childState) -> atom.deserializers.deserialize(childState, {container})
    params

  serializeParams: ->
    children: @children.map (child) -> child.serialize()
    orientation: @orientation

  getViewClass: ->
    if @orientation is 'vertical'
      PaneColumnView ?= require './pane-column-view'
    else
      PaneRowView ?= require './pane-row-view'

  getPanes: ->
    flatten(@children.map (child) -> child.getPanes())

  addChild: (child, index=@children.length) ->
    @children.splice(index, 0, child)
    @childAdded(child)

  removeChild: (child) ->
    index = @children.indexOf(child)
    throw new Error("Removing non-existent child") if index is -1
    @children.splice(index, 1)
    @childRemoved(child)
    @reparentLastChild() if @children.length < 2

  replaceChild: (oldChild, newChild) ->
    index = @children.indexOf(oldChild)
    throw new Error("Replacing non-existent child") if index is -1
    @children.splice(index, 1, newChild)
    @childRemoved(oldChild)
    @childAdded(newChild)

  insertChildBefore: (currentChild, newChild) ->
    index = @children.indexOf(currentChild)
    @children.splice(index, 0, newChild)
    @childAdded(newChild)

  insertChildAfter: (currentChild, newChild) ->
    index = @children.indexOf(currentChild)
    @children.splice(index + 1, 0, newChild)
    @childAdded(newChild)

  reparentLastChild: ->
    @parent.replaceChild(this, @children[0])
    @destroy()

  childAdded: (child) ->
    child.parent = this
    child.container = @container
    @subscribe child, 'destroyed', => @removeChild(child)

  childRemoved: (child) ->
    @unsubscribe child
