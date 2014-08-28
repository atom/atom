{find} = require 'underscore-plus'
{Model} = require 'theorist'
Serializable = require 'serializable'
Rx = require 'rx'
Pane = require './pane'

module.exports =
class PaneContainer extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @version: 1

  @properties
    root: -> new Pane
    activePane: null

  previousRoot: null
  activePaneItemObservable: null

  @behavior 'activePaneItem', ->
    @$activePane
      .switch((activePane) -> activePane?.$activeItem)
      .distinctUntilChanged()

  constructor: (params) ->
    super
    @subscribe @$root, @onRootChanged
    @destroyEmptyPanes() if params?.destroyEmptyPanes

  deserializeParams: (params) ->
    params.root = atom.deserializers.deserialize(params.root, container: this)
    params.destroyEmptyPanes = atom.config.get('core.destroyEmptyPanes')
    params.activePane = params.root.getPanes().find (pane) -> pane.id is params.activePaneId
    params

  serializeParams: (params) ->
    root: @root?.serialize()
    activePaneId: @activePane.id

  getRoot: -> @root

  replaceChild: (oldChild, newChild) ->
    throw new Error("Replacing non-existent child") if oldChild isnt @root
    @root = newChild

  getPanes: ->
    @root?.getPanes() ? []

  setActivePane: (@activePane) ->
    @activePaneSubject?.onNext(@activePane)
    @activePane

  getActivePane: ->
    @activePane

  observeActivePane: (fn) ->
    @activePaneSubject ?= new Rx.BehaviorSubject(@getActivePane())
    if fn?
      @activePaneSubject.subscribe(fn)
    else
      @activePaneSubject

  observeActivePaneItem: (fn) ->
    @activePaneItemObservable ?=
      @observeActivePane().flatMapLatest (activePane) -> activePane.observeActiveItem()
    if fn?
      @activePaneItemObservable.subscribe(fn)
    else
      @activePaneItemObservable

  paneForUri: (uri) ->
    find @getPanes(), (pane) -> pane.itemForUri(uri)?

  saveAll: ->
    pane.saveItems() for pane in @getPanes()

  activateNextPane: ->
    panes = @getPanes()
    if panes.length > 1
      currentIndex = panes.indexOf(@activePane)
      nextIndex = (currentIndex + 1) % panes.length
      panes[nextIndex].activate()
      true
    else
      false

  activatePreviousPane: ->
    panes = @getPanes()
    if panes.length > 1
      currentIndex = panes.indexOf(@activePane)
      previousIndex = currentIndex - 1
      previousIndex = panes.length - 1 if previousIndex < 0
      panes[previousIndex].activate()
      true
    else
      false

  onRootChanged: (root) =>
    @unsubscribe(@previousRoot) if @previousRoot?
    @previousRoot = root

    unless root?
      @setActivePane(null)
      return

    root.setParent(this)
    root.setContainer(this)

    @setActivePane(root) if not @activePane? and root instanceof Pane

  destroyEmptyPanes: ->
    pane.destroy() for pane in @getPanes() when pane.items.length is 0

  itemDestroyed: (item) ->
    @emit 'item-destroyed', item

  # Called by Model superclass when destroyed
  destroyed: ->
    pane.destroy() for pane in @getPanes()
