{find, flatten} = require 'underscore-plus'
{Model} = require 'theorist'
{Emitter, CompositeDisposable} = require 'event-kit'
Serializable = require 'serializable'
Pane = require './pane'
PaneElement = require './pane-element'
PaneContainerElement = require './pane-container-element'
PaneAxisElement = require './pane-axis-element'
PaneAxis = require './pane-axis'
TextEditor = require './text-editor'
TextEditorElement = require './text-editor-element'
ItemRegistry = require './item-registry'

module.exports =
class PaneContainer extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @version: 1

  @properties
    activePane: null

  root: null

  @behavior 'activePaneItem', ->
    @$activePane
      .switch((activePane) -> activePane?.$activeItem)
      .distinctUntilChanged()

  constructor: (params) ->
    super

    @emitter = new Emitter
    @subscriptions = new CompositeDisposable

    @itemRegistry = new ItemRegistry
    @registerViewProviders()

    @setRoot(params?.root ? new Pane)
    @setActivePane(@getPanes()[0]) unless @getActivePane()

    @destroyEmptyPanes() if params?.destroyEmptyPanes

    @monitorActivePaneItem()
    @monitorPaneItems()

  deserializeParams: (params) ->
    params.root = atom.deserializers.deserialize(params.root, container: this)
    params.destroyEmptyPanes = atom.config.get('core.destroyEmptyPanes')
    params.activePane = params.root.getPanes().find (pane) -> pane.id is params.activePaneId
    params

  serializeParams: (params) ->
    root: @root?.serialize()
    activePaneId: @activePane.id

  registerViewProviders: ->
    atom.views.addViewProvider PaneContainer, (model) ->
      new PaneContainerElement().initialize(model)
    atom.views.addViewProvider PaneAxis, (model) ->
      new PaneAxisElement().initialize(model)
    atom.views.addViewProvider Pane, (model) ->
      new PaneElement().initialize(model)
    atom.views.addViewProvider TextEditor, (model) ->
      new TextEditorElement().initialize(model)

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

  paneForUri: (uri) ->
    find @getPanes(), (pane) -> pane.itemForUri(uri)?

  paneForItem: (item) ->
    @getPanes().find (pane) -> item in pane.getItems()

  saveAll: ->
    pane.saveItems() for pane in @getPanes()

  confirmClose: ->
    allSaved = true

    for pane in @getPanes()
      for item in pane.getItems()
        unless pane.promptToSaveItem(item)
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

  willDestroyPaneItem: (event) ->
    @emitter.emit 'will-destroy-pane-item', event

  didDestroyPaneItem: (event) ->
    @emitter.emit 'did-destroy-pane-item', event

  didAddPane: (event) ->
    @emitter.emit 'did-add-pane', event

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
