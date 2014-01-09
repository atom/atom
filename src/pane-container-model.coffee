{Model} = require 'theorist'
Serializable = require 'serializable'
{find} = require 'underscore-plus'
FocusContext = require './focus-context'

module.exports =
class PaneContainerModel extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @properties
    root: null
    focusContext: -> new FocusContext

  constructor: ->
    super
    @subscribe @$root, (root) =>
      if root?
        root.parent = this
        root.focusContext = @focusContext

  deserializeParams: (params) ->
    params.focusContext ?= new FocusContext
    params.root = atom.deserializers.deserialize(params.root, focusContext: params.focusContext)
    params

  serializeParams: (params) ->
    root: @root?.serialize()

  replaceChild: (oldChild, newChild) ->
    throw new Error("Replacing non-existent child") if oldChild isnt @root
    @root = newChild

  getPanes: ->
    @root?.getPanes() ? []

  getFocusedPane: ->
    find @getPanes(), (pane) -> pane.focused

  focusNextPane: ->
    panes = @getPanes()
    if panes.length > 1
      currentIndex = panes.indexOf(@getFocusedPane())
      nextIndex = (currentIndex + 1) % panes.length
      panes[nextIndex].focus()
      true
    else
      false

  focusPreviousPane: ->
    panes = @getPanes()
    if panes.length > 1
      currentIndex = panes.indexOf(@getFocusedPane())
      previousIndex = currentIndex - 1
      previousIndex = panes.length - 1 if previousIndex < 0
      panes[previousIndex].focus()
      true
    else
      false
