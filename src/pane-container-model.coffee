{Model} = require 'theorist'
Serializable = require 'serializable'
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
    @$activePane.switch (activePane) -> activePane?.$activeItem

  constructor: (params) ->
    super
    @subscribe @$root, @onRootChanged
    @destroyEmptyPanes() if params?.destroyEmptyPanes

  deserializeParams: (params) ->
    params.root = atom.deserializers.deserialize(params.root, container: this)
    params.destroyEmptyPanes = true
    params

  serializeParams: (params) ->
    root: @root?.serialize()

  replaceChild: (oldChild, newChild) ->
    throw new Error("Replacing non-existent child") if oldChild isnt @root
    @root = newChild

  getPanes: ->
    @root?.getPanes() ? []

  activateNextPane: ->
    panes = @getPanes()
    if panes.length > 1
      currentIndex = panes.indexOf(@activePane)
      nextIndex = (currentIndex + 1) % panes.length
      panes[nextIndex].activate()
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

  destroyEmptyPanes: ->
    pane.destroy() for pane in @getPanes() when pane.items.length is 0
