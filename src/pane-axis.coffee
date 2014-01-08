Serializable = require 'serializable'
{$, View} = require './space-pen-extensions'
PaneAxisModel = require './pane-axis-model'

### Internal ###
module.exports =
class PaneAxis extends View
  Serializable.includeInto(this)

  initialize: ({children}={}) ->
    @model = new PaneAxisModel
    @model.children.on 'changed', ({index, removedValues, insertedValues}) =>
      @onChildRemoved(child, index) for child in removedValues
      @onChildAdded(child, index) for child in insertedValues

    @addChild(child) for child in children ? []

  serializeParams: ->
    children: @children().views().map (child) -> child.serialize()

  deserializeParams: (params) ->
    params.children = params.children.map (childState) -> atom.deserializers.deserialize(childState)
    params

  addChild: (child, index) ->
    @model.addChild(child, index)

  removeChild: (child) ->
    @model.removeChild(child)

  onChildAdded: (child, index) =>
    @insertAt(index, child)

  onChildRemoved: (child) =>
    parent = @parent().view()
    container = @getContainer()
    childWasInactive = not child.isActive?()

    primitiveRemove = (child) =>
      node = child[0]
      $.cleanData(node.getElementsByTagName('*'))
      $.cleanData([node])
      this[0].removeChild(node)

    # use primitive .removeChild() dom method instead of .remove() to avoid recursive loop
    if @children().length == 2
      primitiveRemove(child)
      sibling = @children().view()
      siblingFocused = sibling.is(':has(:focus)')
      sibling.detach()

      if parent.setRoot?
        parent.setRoot(sibling, suppressPaneItemChangeEvents: childWasInactive)
      else
        parent.insertChildBefore(this, sibling)
        parent.removeChild(this)
      sibling.focus() if siblingFocused
    else
      primitiveRemove(child)

    Pane = require './pane'
    container.trigger 'pane:removed', [child] if child instanceof Pane

  detachChild: (child) ->
    child.detach()

  getContainer: ->
    @closest('.panes').view()

  getActivePaneItem: ->
    @getActivePane()?.activeItem

  getActivePane: ->
    @find('.pane.active').view() ? @find('.pane:first').view()

  insertChildBefore: (currentChild, newChild) ->
    @model.insertChildBefore(currentChild, newChild)

  insertChildAfter: (currentChild, newChild) ->
    @model.insertChildAfter(currentChild, newChild)
