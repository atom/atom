{find, flatten} = require 'underscore-plus'
Grim = require 'grim'
{Emitter, CompositeDisposable} = require 'event-kit'
Serializable = require 'serializable'
Gutter = require './gutter'
Model = require './model'
Pane = require './pane'
ItemRegistry = require './item-registry'

module.exports =
class PaneContainer extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @version: 1

  root: null

  constructor: (params) ->
    super

    unless Grim.includeDeprecatedAPIs
      @activePane = params?.activePane

    @emitter = new Emitter
    @subscriptions = new CompositeDisposable

    @itemRegistry = new ItemRegistry

    @setRoot(params?.root ? new Pane)
    @setActivePane(@getPanes()[0]) unless @getActivePane()

    @destroyEmptyPanes() if params?.destroyEmptyPanes

    @monitorActivePaneItem()
    @monitorPaneItems()

  deserializeParams: (params) ->
    params.root = atom.deserializers.deserialize(params.root, container: this)
    params.destroyEmptyPanes = atom.config.get('core.destroyEmptyPanes')
    params.activePane = find params.root.getPanes(), (pane) -> pane.id is params.activePaneId
    params

  serializeParams: (params) ->
    root: @root?.serialize()
    activePaneId: @activePane.id

  onDidChangeRoot: (fn) ->
    @emitter.on 'did-change-root', fn

  observeRoot: (fn) ->
    fn(@getRoot())
    @onDidChangeRoot(fn)

  onDidAddPane: (fn) ->
    @emitter.on 'did-add-pane', fn

  observePanes: (fn) ->
    fn(pane) for pane in @getPanes()
    @onDidAddPane ({pane}) -> fn(pane)

  onDidDestroyPane: (fn) ->
    @emitter.on 'did-destroy-pane', fn

  onWillDestroyPane: (fn) ->
    @emitter.on 'will-destroy-pane', fn

  onDidChangeActivePane: (fn) ->
    @emitter.on 'did-change-active-pane', fn

  observeActivePane: (fn) ->
    fn(@getActivePane())
    @onDidChangeActivePane(fn)

  onDidAddPaneItem: (fn) ->
    @emitter.on 'did-add-pane-item', fn

  observePaneItems: (fn) ->
    fn(item) for item in @getPaneItems()
    @onDidAddPaneItem ({item}) -> fn(item)

  onDidChangeActivePaneItem: (fn) ->
    @emitter.on 'did-change-active-pane-item', fn

  observeActivePaneItem: (fn) ->
    fn(@getActivePaneItem())
    @onDidChangeActivePaneItem(fn)

  onWillDestroyPaneItem: (fn) ->
    @emitter.on 'will-destroy-pane-item', fn

  onDidDestroyPaneItem: (fn) ->
    @emitter.on 'did-destroy-pane-item', fn

  getRoot: -> @root

  setRoot: (@root) ->
    @root.setParent(this)
    @root.setContainer(this)
    @emitter.emit 'did-change-root', @root
    if not @getActivePane()? and @root instanceof Pane
      @setActivePane(@root)

  replaceChild: (oldChild, newChild) ->
    throw new Error("Replacing non-existent child") if oldChild isnt @root
    @setRoot(newChild)

  getPanes: ->
    @getRoot().getPanes()

  getPaneItems: ->
    @getRoot().getItems()

  getActivePane: ->
    @activePane

  setActivePane: (activePane) ->
    if activePane isnt @activePane
      unless activePane in @getPanes()
        throw new Error("Setting active pane that is not present in pane container")

      @activePane = activePane
      @emitter.emit 'did-change-active-pane', @activePane
    @activePane

  getActivePaneItem: ->
    @getActivePane().getActiveItem()

  paneForURI: (uri) ->
    find @getPanes(), (pane) -> pane.itemForURI(uri)?

  paneForItem: (item) ->
    find @getPanes(), (pane) -> item in pane.getItems()

  saveAll: ->
    pane.saveItems() for pane in @getPanes()
    return

  confirmClose: (options) ->
    allSaved = true

    for pane in @getPanes()
      for item in pane.getItems()
        unless pane.promptToSaveItem(item, options)
          allSaved = false
          break

    allSaved

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

  destroyEmptyPanes: ->
    pane.destroy() for pane in @getPanes() when pane.items.length is 0
    return

  willDestroyPaneItem: (event) ->
    @emitter.emit 'will-destroy-pane-item', event

  didDestroyPaneItem: (event) ->
    @emitter.emit 'did-destroy-pane-item', event

  didAddPane: (event) ->
    @emitter.emit 'did-add-pane', event

  willDestroyPane: (event) ->
    @emitter.emit 'will-destroy-pane', event

  didDestroyPane: (event) ->
    @emitter.emit 'did-destroy-pane', event

  # Called by Model superclass when destroyed
  destroyed: ->
    pane.destroy() for pane in @getPanes()
    @subscriptions.dispose()
    @emitter.dispose()

  monitorActivePaneItem: ->
    childSubscription = null
    @subscriptions.add @observeActivePane (activePane) =>
      if childSubscription?
        @subscriptions.remove(childSubscription)
        childSubscription.dispose()

      childSubscription = activePane.observeActiveItem (activeItem) =>
        @emitter.emit 'did-change-active-pane-item', activeItem

      @subscriptions.add(childSubscription)

  monitorPaneItems: ->
    @subscriptions.add @observePanes (pane) =>
      for item, index in pane.getItems()
        @addedPaneItem(item, pane, index)

      pane.onDidAddItem ({item, index}) =>
        @addedPaneItem(item, pane, index)

      pane.onDidRemoveItem ({item}) =>
        @removedPaneItem(item)

  addedPaneItem: (item, pane, index) ->
    @itemRegistry.addItem(item)
    @emitter.emit 'did-add-pane-item', {item, pane, index}

  removedPaneItem: (item) ->
    @itemRegistry.removeItem(item)

if Grim.includeDeprecatedAPIs
  PaneContainer.properties
    activePane: null

  PaneContainer.behavior 'activePaneItem', ->
    @$activePane
      .switch((activePane) -> activePane?.$activeItem)
      .distinctUntilChanged()
