{Model} = require 'theorist'
Serializable = require 'serializable'
{find} = require 'underscore-plus'
PaneModel = require './pane-model'

module.exports =
class PaneContainerModel extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @properties
    root: null
    activePane: null

  previousRoot: null

  @behavior 'activePaneItem', ->
    @$activePane.flatMapLatest (activePane) -> activePane?.$activeItem

  constructor: ->
    super
    @subscribe @$root, @onRootChanged

  deserializeParams: (params) ->
    params.root = atom.deserializers.deserialize(params.root, container: this)
    params

  serializeParams: (params) ->
    root: @root?.serialize()

  replaceChild: (oldChild, newChild) ->
    throw new Error("Replacing non-existent child") if oldChild isnt @root
    @root = newChild

  getPanes: ->
    @root?.getPanes() ? []

  makeNextPaneActive: ->
    panes = @getPanes()
    if panes.length > 1
      currentIndex = panes.indexOf(@activePane)
      nextIndex = (currentIndex + 1) % panes.length
      @activePane = panes[nextIndex]
    else
      @activePane = null

  onRootChanged: (root) =>
    @unsubscribe(@previousRoot) if @previousRoot?
    @previousRoot = root

    unless root?
      @activePane = null
      return

    root.parent = this
    root.container = this

    if root instanceof PaneModel
      @activePane ?= root
      @subscribe root, 'destroyed', =>
        @activePane = null
        @root = null
