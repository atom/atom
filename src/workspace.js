'use babel'

const _ = require('underscore-plus')
const url = require('url')
const path = require('path')
const {Emitter, Disposable, CompositeDisposable} = require('event-kit')
const fs = require('fs-plus')
const {Directory} = require('pathwatcher')
const DefaultDirectorySearcher = require('./default-directory-searcher')
const Dock = require('./dock')
const Model = require('./model')
const StateStore = require('./state-store')
const TextEditor = require('./text-editor')
const PaneContainer = require('./pane-container')
const Pane = require('./pane')
const Panel = require('./panel')
const PanelContainer = require('./panel-container')
const Task = require('./task')
const WorkspaceCenter = require('./workspace-center')
const WorkspaceElement = require('./workspace-element')

// Essential: Represents the state of the user interface for the entire window.
// An instance of this class is available via the `atom.workspace` global.
//
// Interact with this object to open files, be notified of current and future
// editors, and manipulate panes. To add panels, use {Workspace::addTopPanel}
// and friends.
//
// * `editor` {TextEditor} the new editor
//
module.exports = class Workspace extends Model {
  constructor (params) {
    super(...arguments)

    this.updateWindowTitle = this.updateWindowTitle.bind(this)
    this.updateDocumentEdited = this.updateDocumentEdited.bind(this)
    this.didDestroyPaneItem = this.didDestroyPaneItem.bind(this)
    this.didChangeActivePaneItem = this.didChangeActivePaneItem.bind(this)
    this.didChangeActivePaneOnPaneContainer = this.didChangeActivePaneOnPaneContainer.bind(this)
    this.didChangeActivePaneItemOnPaneContainer = this.didChangeActivePaneItemOnPaneContainer.bind(this)
    this.didActivatePaneContainer = this.didActivatePaneContainer.bind(this)
    this.didHideDock = this.didHideDock.bind(this)

    this.packageManager = params.packageManager
    this.config = params.config
    this.project = params.project
    this.notificationManager = params.notificationManager
    this.viewRegistry = params.viewRegistry
    this.grammarRegistry = params.grammarRegistry
    this.applicationDelegate = params.applicationDelegate
    this.assert = params.assert
    this.deserializerManager = params.deserializerManager
    this.textEditorRegistry = params.textEditorRegistry
    this.styleManager = params.styleManager
    this.hoveredDock = null
    this.draggingItem = false
    this.itemLocationStore = new StateStore('AtomPreviousItemLocations', 1)

    this.emitter = new Emitter()
    this.openers = []
    this.destroyedItemURIs = []

    this.paneContainer = new PaneContainer({
      location: 'center',
      config: this.config,
      applicationDelegate: this.applicationDelegate,
      notificationManager: this.notificationManager,
      deserializerManager: this.deserializerManager,
      viewRegistry: this.viewRegistry
    })
    this.paneContainer.onDidDestroyPaneItem(this.didDestroyPaneItem)

    this.defaultDirectorySearcher = new DefaultDirectorySearcher()
    this.consumeServices(this.packageManager)

    this.center = new WorkspaceCenter({
      paneContainer: this.paneContainer,
      didActivate: this.didActivatePaneContainer,
      didChangeActivePaneItem: this.didChangeActivePaneItemOnPaneContainer
    })
    this.docks = {
      left: this.createDock('left'),
      right: this.createDock('right'),
      bottom: this.createDock('bottom')
    }
    this.activePaneContainer = this.center

    this.panelContainers = {
      top: new PanelContainer({viewRegistry: this.viewRegistry, location: 'top'}),
      left: new PanelContainer({viewRegistry: this.viewRegistry, location: 'left', dock: this.docks.left}),
      right: new PanelContainer({viewRegistry: this.viewRegistry, location: 'right', dock: this.docks.right}),
      bottom: new PanelContainer({viewRegistry: this.viewRegistry, location: 'bottom', dock: this.docks.bottom}),
      header: new PanelContainer({viewRegistry: this.viewRegistry, location: 'header'}),
      footer: new PanelContainer({viewRegistry: this.viewRegistry, location: 'footer'}),
      modal: new PanelContainer({viewRegistry: this.viewRegistry, location: 'modal'})
    }

    this.subscribeToEvents()
  }

  getElement () {
    if (!this.element) {
      this.element = new WorkspaceElement().initialize(this, {
        config: this.config,
        project: this.project,
        viewRegistry: this.viewRegistry,
        styleManager: this.styleManager
      })
    }
    return this.element
  }

  createDock (location) {
    const dock = new Dock({
      location,
      config: this.config,
      applicationDelegate: this.applicationDelegate,
      deserializerManager: this.deserializerManager,
      notificationManager: this.notificationManager,
      viewRegistry: this.viewRegistry,
      didHide: this.didHideDock,
      didActivate: this.didActivatePaneContainer,
      didChangeActivePane: this.didChangeActivePaneOnPaneContainer,
      didChangeActivePaneItem: this.didChangeActivePaneItemOnPaneContainer
    })
    dock.onDidDestroyPaneItem(this.didDestroyPaneItem)
    return dock
  }

  reset (packageManager) {
    this.packageManager = packageManager
    this.emitter.dispose()
    this.emitter = new Emitter()

    this.paneContainer.destroy()
    _.values(this.panelContainers).forEach(panelContainer => { panelContainer.destroy() })

    this.paneContainer = new PaneContainer({
      location: 'center',
      config: this.config,
      applicationDelegate: this.applicationDelegate,
      notificationManager: this.notificationManager,
      deserializerManager: this.deserializerManager,
      viewRegistry: this.viewRegistry
    })
    this.paneContainer.onDidDestroyPaneItem(this.didDestroyPaneItem)

    this.center = new WorkspaceCenter({
      paneContainer: this.paneContainer,
      didActivate: this.didActivatePaneContainer,
      didChangeActivePaneItem: this.didChangeActivePaneItemOnPaneContainer
    })
    this.docks = {
      left: this.createDock('left'),
      right: this.createDock('right'),
      bottom: this.createDock('bottom')
    }
    this.activePaneContainer = this.center

    this.panelContainers = {
      top: new PanelContainer({viewRegistry: this.viewRegistry, location: 'top'}),
      left: new PanelContainer({viewRegistry: this.viewRegistry, location: 'left', dock: this.docks.left}),
      right: new PanelContainer({viewRegistry: this.viewRegistry, location: 'right', dock: this.docks.right}),
      bottom: new PanelContainer({viewRegistry: this.viewRegistry, location: 'bottom', dock: this.docks.bottom}),
      header: new PanelContainer({viewRegistry: this.viewRegistry, location: 'header'}),
      footer: new PanelContainer({viewRegistry: this.viewRegistry, location: 'footer'}),
      modal: new PanelContainer({viewRegistry: this.viewRegistry, location: 'modal'})
    }

    this.originalFontSize = null
    this.openers = []
    this.destroyedItemURIs = []
    this.element = null
    this.consumeServices(this.packageManager)
  }

  subscribeToEvents () {
    this.subscribeToActiveItem()
    this.subscribeToFontSize()
    this.subscribeToAddedItems()
    this.subscribeToMovedItems()
  }

  consumeServices ({serviceHub}) {
    this.directorySearchers = []
    serviceHub.consume(
      'atom.directory-searcher',
      '^0.1.0',
      provider => this.directorySearchers.unshift(provider)
    )
  }

  // Called by the Serializable mixin during serialization.
  serialize () {
    return {
      deserializer: 'Workspace',
      paneContainer: this.paneContainer.serialize(),
      packagesWithActiveGrammars: this.getPackageNamesWithActiveGrammars(),
      destroyedItemURIs: this.destroyedItemURIs.slice(),
      docks: {
        left: this.docks.left.serialize(),
        right: this.docks.right.serialize(),
        bottom: this.docks.bottom.serialize()
      }
    }
  }

  deserialize (state, deserializerManager) {
    const packagesWithActiveGrammars =
      state.packagesWithActiveGrammars != null ? state.packagesWithActiveGrammars : []
    for (let packageName of packagesWithActiveGrammars) {
      const pkg = this.packageManager.getLoadedPackage(packageName)
      if (pkg != null) {
        pkg.loadGrammarsSync()
      }
    }
    if (state.destroyedItemURIs != null) {
      this.destroyedItemURIs = state.destroyedItemURIs
    }
    this.paneContainer.deserialize(state.paneContainer, deserializerManager)
    for (let location in this.docks) {
      const serialized = state.docks && state.docks[location]
      if (serialized) {
        this.docks[location].deserialize(serialized, deserializerManager)
      }
    }
    this.updateWindowTitle()
  }

  getPackageNamesWithActiveGrammars () {
    const packageNames = []
    const addGrammar = ({includedGrammarScopes, packageName} = {}) => {
      if (!packageName) { return }
      // Prevent cycles
      if (packageNames.indexOf(packageName) !== -1) { return }

      packageNames.push(packageName)
      for (let scopeName of includedGrammarScopes != null ? includedGrammarScopes : []) {
        addGrammar(this.grammarRegistry.grammarForScopeName(scopeName))
      }
    }

    const editors = this.getTextEditors()
    for (let editor of editors) { addGrammar(editor.getGrammar()) }

    if (editors.length > 0) {
      for (let grammar of this.grammarRegistry.getGrammars()) {
        if (grammar.injectionSelector) {
          addGrammar(grammar)
        }
      }
    }

    return _.uniq(packageNames)
  }

  didActivatePaneContainer (paneContainer) {
    if (paneContainer !== this.getActivePaneContainer()) {
      this.activePaneContainer = paneContainer
      if (global.debug) debugger
      this.emitter.emit('did-change-active-pane-container', this.activePaneContainer)
      this.emitter.emit('did-change-active-pane', this.activePaneContainer.getActivePane())
      this.emitter.emit('did-change-active-pane-item', this.activePaneContainer.getActivePaneItem())
    }
  }

  didChangeActivePaneOnPaneContainer (paneContainer, pane) {
    if (paneContainer === this.getActivePaneContainer()) {
      this.emitter.emit('did-change-active-pane', pane)
    }
  }

  didChangeActivePaneItemOnPaneContainer (paneContainer, item) {
    if (paneContainer === this.getActivePaneContainer()) {
      this.emitter.emit('did-change-active-pane-item', item)
    }
  }

  didHideDock () {
    this.getCenter().activate()
  }

  setHoveredDock (hoveredDock) {
    this.hoveredDock = hoveredDock
    _.values(this.docks).forEach(dock => {
      dock.setHovered(dock === hoveredDock)
    })
  }

  setDraggingItem (draggingItem) {
    _.values(this.docks).forEach(dock => {
      dock.setDraggingItem(draggingItem)
    })
  }

  subscribeToActiveItem () {
    this.project.onDidChangePaths(this.updateWindowTitle)
    this.onDidChangeActivePaneItem(this.didChangeActivePaneItem)
  }

  didChangeActivePaneItem (item) {
    this.updateWindowTitle()
    this.updateDocumentEdited()
    if (this.activeItemSubscriptions != null) {
      this.activeItemSubscriptions.dispose()
    }
    this.activeItemSubscriptions = new CompositeDisposable()

    let modifiedSubscription, titleSubscription

    if (item != null && typeof item.onDidChangeTitle === 'function') {
      titleSubscription = item.onDidChangeTitle(this.updateWindowTitle)
    } else if (item != null && typeof item.on === 'function') {
      titleSubscription = item.on('title-changed', this.updateWindowTitle)
      if (titleSubscription == null || typeof titleSubscription.dispose !== 'function') {
        titleSubscription = new Disposable(() => {
          item.off('title-changed', this.updateWindowTitle)
        })
      }
    }

    if (item != null && typeof item.onDidChangeModified === 'function') {
      modifiedSubscription = item.onDidChangeModified(this.updateDocumentEdited)
    } else if (item != null && typeof item.on === 'function') {
      modifiedSubscription = item.on('modified-status-changed', this.updateDocumentEdited)
      if (modifiedSubscription == null || typeof modifiedSubscription.dispose !== 'function') {
        modifiedSubscription = new Disposable(() => {
          item.off('modified-status-changed', this.updateDocumentEdited)
        })
      }
    }

    if (titleSubscription != null) { this.activeItemSubscriptions.add(titleSubscription) }
    if (modifiedSubscription != null) { this.activeItemSubscriptions.add(modifiedSubscription) }
  }

  subscribeToAddedItems () {
    this.onDidAddPaneItem(({item, pane, index}) => {
      if (item instanceof TextEditor) {
        const subscriptions = new CompositeDisposable(
          this.textEditorRegistry.add(item),
          this.textEditorRegistry.maintainGrammar(item),
          this.textEditorRegistry.maintainConfig(item),
          item.observeGrammar(this.handleGrammarUsed.bind(this))
        )
        item.onDidDestroy(() => { subscriptions.dispose() })
        this.emitter.emit('did-add-text-editor', {textEditor: item, pane, index})
      }
    })
  }

  subscribeToMovedItems () {
    for (const paneContainer of this.getPaneContainers()) {
      paneContainer.observePanes(pane => {
        pane.onDidAddItem(({item}) => {
          if (typeof item.getURI === 'function') {
            const uri = item.getURI()
            if (uri != null) {
              const location = paneContainer.getLocation()
              let defaultLocation
              if (typeof item.getDefaultLocation === 'function') {
                defaultLocation = item.getDefaultLocation()
              }
              defaultLocation = defaultLocation || 'center'
              if (location === defaultLocation) {
                this.itemLocationStore.delete(item.getURI())
              } else {
                this.itemLocationStore.save(item.getURI(), location)
              }
            }
          }
        })
      })
    }
  }

  // Updates the application's title and proxy icon based on whichever file is
  // open.
  updateWindowTitle () {
    let itemPath, itemTitle, projectPath, representedPath
    const appName = 'Atom'
    const left = this.project.getPaths()
    const projectPaths = left != null ? left : []
    const item = this.getActivePaneItem()
    if (item) {
      itemPath = typeof item.getPath === 'function' ? item.getPath() : undefined
      const longTitle = typeof item.getLongTitle === 'function' ? item.getLongTitle() : undefined
      itemTitle = longTitle == null
        ? (typeof item.getTitle === 'function' ? item.getTitle() : undefined)
        : longTitle
      projectPath = _.find(
        projectPaths,
        projectPath =>
          (itemPath === projectPath) || (itemPath != null ? itemPath.startsWith(projectPath + path.sep) : undefined)
      )
    }
    if (itemTitle == null) { itemTitle = 'untitled' }
    if (projectPath == null) { projectPath = itemPath ? path.dirname(itemPath) : projectPaths[0] }
    if (projectPath != null) {
      projectPath = fs.tildify(projectPath)
    }

    const titleParts = []
    if ((item != null) && (projectPath != null)) {
      titleParts.push(itemTitle, projectPath)
      representedPath = itemPath != null ? itemPath : projectPath
    } else if (projectPath != null) {
      titleParts.push(projectPath)
      representedPath = projectPath
    } else {
      titleParts.push(itemTitle)
      representedPath = ''
    }

    if (process.platform !== 'darwin') {
      titleParts.push(appName)
    }

    document.title = titleParts.join(' \u2014 ')
    this.applicationDelegate.setRepresentedFilename(representedPath)
  }

  // On macOS, fades the application window's proxy icon when the current file
  // has been modified.
  updateDocumentEdited () {
    const activePaneItem = this.getActivePaneItem()
    const modified = activePaneItem != null && typeof activePaneItem.isModified === 'function'
      ? activePaneItem.isModified() || false
      : false
    this.applicationDelegate.setWindowDocumentEdited(modified)
  }

  /*
  Section: Event Subscription
  */

  onDidChangeActivePaneContainer (callback) {
    return this.emitter.on('did-change-active-pane-container', callback)
  }

  // Essential: Invoke the given callback with all current and future text
  // editors in the workspace.
  //
  // * `callback` {Function} to be called with current and future text editors.
  //   * `editor` An {TextEditor} that is present in {::getTextEditors} at the time
  //     of subscription or that is added at some later time.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeTextEditors (callback) {
    for (let textEditor of this.getTextEditors()) { callback(textEditor) }
    return this.onDidAddTextEditor(({textEditor}) => callback(textEditor))
  }

  // Essential: Invoke the given callback with all current and future panes items
  // in the workspace.
  //
  // * `callback` {Function} to be called with current and future pane items.
  //   * `item` An item that is present in {::getPaneItems} at the time of
  //      subscription or that is added at some later time.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observePaneItems (callback) {
    return new CompositeDisposable(
      ...this.getPaneContainers().map(container => container.observePaneItems(callback))
    )
  }

  // Essential: Invoke the given callback when the active pane item changes.
  //
  // Because observers are invoked synchronously, it's important not to perform
  // any expensive operations via this method. Consider
  // {::onDidStopChangingActivePaneItem} to delay operations until after changes
  // stop occurring.
  //
  // * `callback` {Function} to be called when the active pane item changes.
  //   * `item` The active pane item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActivePaneItem (callback) {
    return this.emitter.on('did-change-active-pane-item', callback)
  }

  // Essential: Invoke the given callback when the active pane item stops
  // changing.
  //
  // Observers are called asynchronously 100ms after the last active pane item
  // change. Handling changes here rather than in the synchronous
  // {::onDidChangeActivePaneItem} prevents unneeded work if the user is quickly
  // changing or closing tabs and ensures critical UI feedback, like changing the
  // highlighted tab, gets priority over work that can be done asynchronously.
  //
  // * `callback` {Function} to be called when the active pane item stopts
  //   changing.
  //   * `item` The active pane item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidStopChangingActivePaneItem (callback) {
    return this.paneContainer.onDidStopChangingActivePaneItem(callback)
  }

  // Essential: Invoke the given callback with the current active pane item and
  // with all future active pane items in the workspace.
  //
  // * `callback` {Function} to be called when the active pane item changes.
  //   * `item` The current active pane item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActivePaneItem (callback) {
    callback(this.getActivePaneItem())
    return this.onDidChangeActivePaneItem(callback)
  }

  // Essential: Invoke the given callback whenever an item is opened. Unlike
  // {::onDidAddPaneItem}, observers will be notified for items that are already
  // present in the workspace when they are reopened.
  //
  // * `callback` {Function} to be called whenever an item is opened.
  //   * `event` {Object} with the following keys:
  //     * `uri` {String} representing the opened URI. Could be `undefined`.
  //     * `item` The opened item.
  //     * `pane` The pane in which the item was opened.
  //     * `index` The index of the opened item on its pane.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidOpen (callback) {
    return this.emitter.on('did-open', callback)
  }

  // Extended: Invoke the given callback when a pane is added to the workspace.
  //
  // * `callback` {Function} to be called panes are added.
  //   * `event` {Object} with the following keys:
  //     * `pane` The added pane.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddPane (callback) {
    return new CompositeDisposable(
      ...this.getPaneContainers().map(container => container.onDidAddPane(callback))
    )
  }

  // Extended: Invoke the given callback before a pane is destroyed in the
  // workspace.
  //
  // * `callback` {Function} to be called before panes are destroyed.
  //   * `event` {Object} with the following keys:
  //     * `pane` The pane to be destroyed.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillDestroyPane (callback) {
    return new CompositeDisposable(
      ...this.getPaneContainers().map(container => container.onWillDestroyPane(callback))
    )
  }

  // Extended: Invoke the given callback when a pane is destroyed in the
  // workspace.
  //
  // * `callback` {Function} to be called panes are destroyed.
  //   * `event` {Object} with the following keys:
  //     * `pane` The destroyed pane.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroyPane (callback) {
    return new CompositeDisposable(
      ...this.getPaneContainers().map(container => container.onDidDestroyPane(callback))
    )
  }

  // Extended: Invoke the given callback with all current and future panes in the
  // workspace.
  //
  // * `callback` {Function} to be called with current and future panes.
  //   * `pane` A {Pane} that is present in {::getPanes} at the time of
  //      subscription or that is added at some later time.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observePanes (callback) {
    return new CompositeDisposable(
      ...this.getPaneContainers().map(container => container.observePanes(callback))
    )
  }

  // Extended: Invoke the given callback when the active pane changes.
  //
  // * `callback` {Function} to be called when the active pane changes.
  //   * `pane` A {Pane} that is the current return value of {::getActivePane}.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActivePane (callback) {
    return this.emitter.on('did-change-active-pane', callback)
  }

  // Extended: Invoke the given callback with the current active pane and when
  // the active pane changes.
  //
  // * `callback` {Function} to be called with the current and future active#
  //   panes.
  //   * `pane` A {Pane} that is the current return value of {::getActivePane}.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActivePane (callback) {
    callback(this.getActivePane())
    return this.onDidChangeActivePane(callback)
  }

  // Extended: Invoke the given callback when a pane item is added to the
  // workspace.
  //
  // * `callback` {Function} to be called when pane items are added.
  //   * `event` {Object} with the following keys:
  //     * `item` The added pane item.
  //     * `pane` {Pane} containing the added item.
  //     * `index` {Number} indicating the index of the added item in its pane.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddPaneItem (callback) {
    return new CompositeDisposable(
      ...this.getPaneContainers().map(container => container.onDidAddPaneItem(callback))
    )
  }

  // Extended: Invoke the given callback when a pane item is about to be
  // destroyed, before the user is prompted to save it.
  //
  // * `callback` {Function} to be called before pane items are destroyed.
  //   * `event` {Object} with the following keys:
  //     * `item` The item to be destroyed.
  //     * `pane` {Pane} containing the item to be destroyed.
  //     * `index` {Number} indicating the index of the item to be destroyed in
  //       its pane.
  //
  // Returns a {Disposable} on which `.dispose` can be called to unsubscribe.
  onWillDestroyPaneItem (callback) {
    return new CompositeDisposable(
      ...this.getPaneContainers().map(container => container.onWillDestroyPaneItem(callback))
    )
  }

  // Extended: Invoke the given callback when a pane item is destroyed.
  //
  // * `callback` {Function} to be called when pane items are destroyed.
  //   * `event` {Object} with the following keys:
  //     * `item` The destroyed item.
  //     * `pane` {Pane} containing the destroyed item.
  //     * `index` {Number} indicating the index of the destroyed item in its
  //       pane.
  //
  // Returns a {Disposable} on which `.dispose` can be called to unsubscribe.
  onDidDestroyPaneItem (callback) {
    return new CompositeDisposable(
      ...this.getPaneContainers().map(container => container.onDidDestroyPaneItem(callback))
    )
  }

  // Extended: Invoke the given callback when a text editor is added to the
  // workspace.
  //
  // * `callback` {Function} to be called panes are added.
  //   * `event` {Object} with the following keys:
  //     * `textEditor` {TextEditor} that was added.
  //     * `pane` {Pane} containing the added text editor.
  //     * `index` {Number} indicating the index of the added text editor in its
  //        pane.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddTextEditor (callback) {
    return this.emitter.on('did-add-text-editor', callback)
  }

  /*
  Section: Opening
  */

  // Essential: Opens the given URI in Atom asynchronously.
  // If the URI is already open, the existing item for that URI will be
  // activated. If no URI is given, or no registered opener can open
  // the URI, a new empty {TextEditor} will be created.
  //
  // * `uri` (optional) A {String} containing a URI.
  // * `options` (optional) {Object}
  //   * `initialLine` A {Number} indicating which row to move the cursor to
  //     initially. Defaults to `0`.
  //   * `initialColumn` A {Number} indicating which column to move the cursor to
  //     initially. Defaults to `0`.
  //   * `split` Either 'left', 'right', 'up' or 'down'.
  //     If 'left', the item will be opened in leftmost pane of the current active pane's row.
  //     If 'right', the item will be opened in the rightmost pane of the current active pane's row. If only one pane exists in the row, a new pane will be created.
  //     If 'up', the item will be opened in topmost pane of the current active pane's column.
  //     If 'down', the item will be opened in the bottommost pane of the current active pane's column. If only one pane exists in the column, a new pane will be created.
  //   * `activatePane` A {Boolean} indicating whether to call {Pane::activate} on
  //     containing pane. Defaults to `true`.
  //   * `activateItem` A {Boolean} indicating whether to call {Pane::activateItem}
  //     on containing pane. Defaults to `true`.
  //   * `pending` A {Boolean} indicating whether or not the item should be opened
  //     in a pending state. Existing pending items in a pane are replaced with
  //     new pending items when they are opened.
  //   * `searchAllPanes` A {Boolean}. If `true`, the workspace will attempt to
  //     activate an existing item for the given URI on any pane.
  //     If `false`, only the active pane will be searched for
  //     an existing item for the same URI. Defaults to `false`.
  //   * `location` (optional) A {String} containing the name of the location
  //     in which this item should be opened (one of "left", "right", "bottom",
  //     or "center"). If omitted, Atom will fall back to the last location in
  //     which a user has placed an item with the same URI or, if this is a new
  //     URI, the default location specified by the item. NOTE: This option
  //     should almost always be omitted to honor user preference.
  //
  // Returns a {Promise} that resolves to the {TextEditor} for the file URI.
  async open (itemOrURI, options = {}) {
    let uri, item
    if (typeof itemOrURI === 'string') {
      uri = this.project.resolvePath(itemOrURI)
    } else if (itemOrURI) {
      item = itemOrURI
      if (typeof item.getURI === 'function') uri = item.getURI()
    }

    if (!atom.config.get('core.allowPendingPaneItems')) {
      options.pending = false
    }

    // Avoid adding URLs as recent documents to work-around this Spotlight crash:
    // https://github.com/atom/atom/issues/10071
    if (uri && (!url.parse(uri).protocol || process.platform === 'win32')) {
      this.applicationDelegate.addRecentDocument(uri)
    }

    let container, pane, itemExistsInWorkspace

    // Try to find an existing item in the workspace.
    if (item || uri) {
      if (options.pane) {
        pane = options.pane
      } else if (options.searchAllPanes) {
        pane = item ? this.paneForItem(item) : this.paneForURI(uri)
      } else {
        // The `split` option affects where we search for the item.
        pane = this.getActivePane()
        switch (options.split) {
          case 'left':
            pane = pane.findLeftmostSibling()
            break
          case 'right':
            pane = pane.findRightmostSibling()
            break
          case 'up':
            pane = pane.findTopmostSibling()
            break
          case 'down':
            pane = pane.findBottommostSibling()
            break
        }
      }

      if (pane) {
        if (item) {
          itemExistsInWorkspace = pane.getItems().includes(item)
        } else {
          item = pane.itemForURI(uri)
          itemExistsInWorkspace = item != null
        }
      }
    }

    // If we already have an item at this stage, we won't need to do an async
    // lookup of the URI, so we yield the event loop to ensure this method
    // is consistently asynchronous.
    if (item) await Promise.resolve()

    if (!itemExistsInWorkspace) {
      item = item || await this.createItemForURI(uri, options)
      if (!item) return

      if (options.pane) {
        pane = options.pane
      } else {
        let location = options.location
        if (!location && !options.split && uri) {
          location = await this.itemLocationStore.load(uri)
        }
        if (!location && typeof item.getDefaultLocation === 'function') {
          location = item.getDefaultLocation()
        }

        const allowedLocations = typeof item.getAllowedLocations === 'function' ? item.getAllowedLocations() : ALL_LOCATIONS
        location = allowedLocations.includes(location) ? location : allowedLocations[0]

        container = this.docks[location] || this.getCenter()
        pane = container.getActivePane()
        switch (options.split) {
          case 'left':
            pane = pane.findLeftmostSibling()
            break
          case 'right':
            pane = pane.findOrCreateRightmostSibling()
            break
          case 'up':
            pane = pane.findTopmostSibling()
            break
          case 'down':
            pane = pane.findOrCreateBottommostSibling()
            break
        }
      }
    }

    if (!options.pending && (pane.getPendingItem() === item)) {
      pane.clearPendingItem()
    }

    this.itemOpened(item)

    if (options.activateItem === false) {
      pane.addItem(item, {pending: options.pending})
    } else {
      pane.activateItem(item, {pending: options.pending})
    }

    if (options.activatePane !== false) {
      pane.activate()
    }

    let initialColumn = 0
    let initialLine = 0
    if (!Number.isNaN(options.initialLine)) {
      initialLine = options.initialLine
    }
    if (!Number.isNaN(options.initialColumn)) {
      initialColumn = options.initialColumn
    }
    if (initialLine >= 0 || initialColumn >= 0) {
      if (typeof item.setCursorBufferPosition === 'function') {
        item.setCursorBufferPosition([initialLine, initialColumn])
      }
    }

    const index = pane.getActiveItemIndex()
    this.emitter.emit('did-open', {uri, pane, item, index})
    return item
  }

  // Essential: Search the workspace for items matching the given URI and hide them.
  //
  // * `itemOrURI` (optional) The item to hide or a {String} containing the URI
  //   of the item to hide.
  //
  // Returns a {boolean} indicating whether any items were found (and hidden).
  hide (itemOrURI) {
    let foundItems = false

    // If any visible item has the given URI, hide it
    for (const container of this.getPaneContainers()) {
      const isCenter = container === this.getCenter()
      if (isCenter || container.isOpen()) {
        for (const pane of container.getPanes()) {
          const activeItem = pane.getActiveItem()
          const foundItem = (
            activeItem != null && (
              activeItem === itemOrURI ||
              typeof activeItem.getURI === 'function' && activeItem.getURI() === itemOrURI
            )
          )
          if (foundItem) {
            foundItems = true
            // We can't really hide the center so we just destroy the item.
            if (isCenter) {
              pane.destroyItem(activeItem)
            } else {
              container.hide()
            }
          }
        }
      }
    }

    return foundItems
  }

  // Essential: Search the workspace for items matching the given URI. If any are found, hide them.
  // Otherwise, open the URL.
  //
  // * `itemOrURI` (optional) The item to toggle or a {String} containing the URI
  //   of the item to toggle.
  //
  // Returns a Promise that resolves when the item is shown or hidden.
  toggle (itemOrURI) {
    if (this.hide(itemOrURI)) {
      return Promise.resolve()
    } else {
      return this.open(itemOrURI, {searchAllPanes: true})
    }
  }

  // Open Atom's license in the active pane.
  openLicense () {
    return this.open(path.join(process.resourcesPath, 'LICENSE.md'))
  }

  // Synchronously open the given URI in the active pane. **Only use this method
  // in specs. Calling this in production code will block the UI thread and
  // everyone will be mad at you.**
  //
  // * `uri` A {String} containing a URI.
  // * `options` An optional options {Object}
  //   * `initialLine` A {Number} indicating which row to move the cursor to
  //     initially. Defaults to `0`.
  //   * `initialColumn` A {Number} indicating which column to move the cursor to
  //     initially. Defaults to `0`.
  //   * `activatePane` A {Boolean} indicating whether to call {Pane::activate} on
  //     the containing pane. Defaults to `true`.
  //   * `activateItem` A {Boolean} indicating whether to call {Pane::activateItem}
  //     on containing pane. Defaults to `true`.
  openSync (uri_ = '', options = {}) {
    const {initialLine, initialColumn} = options
    const activatePane = options.activatePane != null ? options.activatePane : true
    const activateItem = options.activateItem != null ? options.activateItem : true

    const uri = this.project.resolvePath(uri)
    let item = this.getActivePane().itemForURI(uri)
    if (uri && (item == null)) {
      for (const opener of this.getOpeners()) {
        item = opener(uri, options)
        if (item) break
      }
    }
    if (item == null) {
      item = this.project.openSync(uri, {initialLine, initialColumn})
    }

    if (activateItem) {
      this.getActivePane().activateItem(item)
    }
    this.itemOpened(item)
    if (activatePane) {
      this.getActivePane().activate()
    }
    return item
  }

  openURIInPane (uri, pane) {
    return this.open(uri, {pane})
  }

  // Public: Creates a new item that corresponds to the provided URI.
  //
  // If no URI is given, or no registered opener can open the URI, a new empty
  // {TextEditor} will be created.
  //
  // * `uri` A {String} containing a URI.
  //
  // Returns a {Promise} that resolves to the {TextEditor} (or other item) for the given URI.
  createItemForURI (uri, options) {
    if (uri != null) {
      for (let opener of this.getOpeners()) {
        const item = opener(uri, options)
        if (item != null) return Promise.resolve(item)
      }
    }

    try {
      return this.openTextFile(uri, options)
    } catch (error) {
      switch (error.code) {
        case 'CANCELLED':
          return Promise.resolve()
        case 'EACCES':
          this.notificationManager.addWarning(`Permission denied '${error.path}'`)
          return Promise.resolve()
        case 'EPERM':
        case 'EBUSY':
        case 'ENXIO':
        case 'EIO':
        case 'ENOTCONN':
        case 'UNKNOWN':
        case 'ECONNRESET':
        case 'EINVAL':
        case 'EMFILE':
        case 'ENOTDIR':
        case 'EAGAIN':
          this.notificationManager.addWarning(
            `Unable to open '${error.path != null ? error.path : uri}'`,
            {detail: error.message}
          )
          return Promise.resolve()
        default:
          throw error
      }
    }
  }

  openTextFile (uri, options) {
    const filePath = this.project.resolvePath(uri)

    if (filePath != null) {
      try {
        fs.closeSync(fs.openSync(filePath, 'r'))
      } catch (error) {
        // allow ENOENT errors to create an editor for paths that dont exist
        if (error.code !== 'ENOENT') {
          throw error
        }
      }
    }

    const fileSize = fs.getSizeSync(filePath)

    const largeFileMode = fileSize >= (2 * 1048576) // 2MB
    if (fileSize >= (this.config.get('core.warnOnLargeFileLimit') * 1048576)) { // 20MB by default
      const choice = this.applicationDelegate.confirm({
        message: 'Atom will be unresponsive during the loading of very large files.',
        detailedMessage: 'Do you still want to load this file?',
        buttons: ['Proceed', 'Cancel']
      })
      if (choice === 1) {
        const error = new Error()
        error.code = 'CANCELLED'
        throw error
      }
    }

    return this.project.bufferForPath(filePath, options)
      .then(buffer => {
        return this.textEditorRegistry.build(Object.assign({buffer, largeFileMode, autoHeight: false}, options))
      })
  }

  handleGrammarUsed (grammar) {
    if (grammar == null) { return }
    return this.packageManager.triggerActivationHook(`${grammar.packageName}:grammar-used`)
  }

  // Public: Returns a {Boolean} that is `true` if `object` is a `TextEditor`.
  //
  // * `object` An {Object} you want to perform the check against.
  isTextEditor (object) {
    return object instanceof TextEditor
  }

  // Extended: Create a new text editor.
  //
  // Returns a {TextEditor}.
  buildTextEditor (params) {
    const editor = this.textEditorRegistry.build(params)
    const subscriptions = new CompositeDisposable(
      this.textEditorRegistry.maintainGrammar(editor),
      this.textEditorRegistry.maintainConfig(editor)
    )
    editor.onDidDestroy(() => { subscriptions.dispose() })
    return editor
  }

  // Public: Asynchronously reopens the last-closed item's URI if it hasn't already been
  // reopened.
  //
  // Returns a {Promise} that is resolved when the item is opened
  reopenItem () {
    const uri = this.destroyedItemURIs.pop()
    if (uri) {
      return this.open(uri)
    } else {
      return Promise.resolve()
    }
  }

  // Public: Register an opener for a uri.
  //
  // When a URI is opened via {Workspace::open}, Atom loops through its registered
  // opener functions until one returns a value for the given uri.
  // Openers are expected to return an object that inherits from HTMLElement or
  // a model which has an associated view in the {ViewRegistry}.
  // A {TextEditor} will be used if no opener returns a value.
  //
  // ## Examples
  //
  // ```coffee
  // atom.workspace.addOpener (uri) ->
  //   if path.extname(uri) is '.toml'
  //     return new TomlEditor(uri)
  // ```
  //
  // * `opener` A {Function} to be called when a path is being opened.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to remove the
  // opener.
  //
  // Note that the opener will be called if and only if the URI is not already open
  // in the current pane. The searchAllPanes flag expands the search from the
  // current pane to all panes. If you wish to open a view of a different type for
  // a file that is already open, consider changing the protocol of the URI. For
  // example, perhaps you wish to preview a rendered version of the file `/foo/bar/baz.quux`
  // that is already open in a text editor view. You could signal this by calling
  // {Workspace::open} on the URI `quux-preview://foo/bar/baz.quux`. Then your opener
  // can check the protocol for quux-preview and only handle those URIs that match.
  addOpener (opener) {
    this.openers.push(opener)
    return new Disposable(() => { _.remove(this.openers, opener) })
  }

  getOpeners () {
    return this.openers
  }

  /*
  Section: Pane Items
  */

  // Essential: Get all pane items in the workspace.
  //
  // Returns an {Array} of items.
  getPaneItems () {
    return _.flatten(this.getPaneContainers().map(container => container.getPaneItems()))
  }

  // Essential: Get the active {Pane}'s active item.
  //
  // Returns an pane item {Object}.
  getActivePaneItem () {
    return this.getActivePaneContainer().getActivePaneItem()
  }

  // Essential: Get all text editors in the workspace.
  //
  // Returns an {Array} of {TextEditor}s.
  getTextEditors () {
    return this.getPaneItems().filter(item => item instanceof TextEditor)
  }

  // Essential: Get the active item if it is an {TextEditor}.
  //
  // Returns an {TextEditor} or `undefined` if the current active item is not an
  // {TextEditor}.
  getActiveTextEditor () {
    const activeItem = this.getActivePaneItem()
    if (activeItem instanceof TextEditor) { return activeItem }
  }

  // Save all pane items.
  saveAll () {
    this.getPaneContainers().forEach(container => {
      container.saveAll()
    })
  }

  confirmClose (options) {
    return this.getPaneContainers()
      .map(container => container.confirmClose(options))
      .every(saved => saved)
  }

  // Save the active pane item.
  //
  // If the active pane item currently has a URI according to the item's
  // `.getURI` method, calls `.save` on the item. Otherwise
  // {::saveActivePaneItemAs} # will be called instead. This method does nothing
  // if the active item does not implement a `.save` method.
  saveActivePaneItem () {
    this.getActivePane().saveActiveItem()
  }

  // Prompt the user for a path and save the active pane item to it.
  //
  // Opens a native dialog where the user selects a path on disk, then calls
  // `.saveAs` on the item with the selected path. This method does nothing if
  // the active item does not implement a `.saveAs` method.
  saveActivePaneItemAs () {
    this.getActivePane().saveActiveItemAs()
  }

  getFocusedPane () {
    let el = document.activeElement
    while (el != null) {
      if (typeof el.getModel === 'function') {
        const model = el.getModel()
        if (model instanceof Pane) return model
      }
      el = el.parentElement
    }
  }

  // Save the currently focused pane item.
  //
  // If the focused pane item currently has a URI according to the item's
  // `.getURI` method, calls `.save` on the item. Otherwise
  // {::saveFocusedPaneItemAs} will be called instead. This method does nothing
  // if the focused item does not implement a `.save` method.
  saveFocusedPaneItem () {
    const pane = this.getFocusedPane()
    if (pane) {
      pane.saveActiveItem()
    }
  }

  // Prompt the user for a path and save the focused pane item to it.
  //
  // Opens a native dialog where the user selects a path on disk, then calls
  // `.saveAs` on the item with the selected path. This method does nothing if
  // the focused item does not implement a `.saveAs` method.
  saveFocusedPaneItemAs () {
    const pane = this.getFocusedPane()
    if (pane) {
      pane.saveActiveItemAs()
    }
  }

  // Destroy (close) the active pane item.
  //
  // Removes the active pane item and calls the `.destroy` method on it if one is
  // defined.
  destroyActivePaneItem () {
    return this.getActivePane().destroyActiveItem()
  }

  /*
  Section: Panes
  */

  getActivePaneContainer () {
    return this.activePaneContainer
  }

  // Extended: Get all panes in the workspace.
  //
  // Returns an {Array} of {Pane}s.
  getPanes () {
    return _.flatten(this.getPaneContainers().map(container => container.getPanes()))
  }

  // Extended: Get the active {Pane}.
  //
  // Returns a {Pane}.
  getActivePane () {
    return this.getActivePaneContainer().getActivePane()
  }

  // Extended: Make the next pane active.
  activateNextPane () {
    return this.paneContainer.activateNextPane()
  }

  // Extended: Make the previous pane active.
  activatePreviousPane () {
    return this.paneContainer.activatePreviousPane()
  }

  // Extended: Get the first {Pane} with an item for the given URI.
  //
  // * `uri` {String} uri
  //
  // Returns a {Pane} or `undefined` if no pane exists for the given URI.
  paneForURI (uri) {
    for (let location of this.getPaneContainers()) {
      const pane = location.paneForURI(uri)
      if (pane != null) {
        return pane
      }
    }
  }

  // Extended: Get the {Pane} containing the given item.
  //
  // * `item` Item the returned pane contains.
  //
  // Returns a {Pane} or `undefined` if no pane exists for the given item.
  paneForItem (item) {
    for (let location of this.getPaneContainers()) {
      const pane = location.paneForItem(item)
      if (pane != null) {
        return pane
      }
    }
  }

  // Destroy (close) the active pane.
  destroyActivePane () {
    const activePane = this.getActivePane()
    if (activePane != null) {
      activePane.destroy()
    }
  }

  // Close the active pane item, or the active pane if it is empty,
  // or the current window if there is only the empty root pane.
  closeActivePaneItemOrEmptyPaneOrWindow () {
    if (this.getActivePaneItem() != null) {
      this.destroyActivePaneItem()
    } else if (this.getCenter().getPanes().length > 1) {
      this.destroyActivePane()
    } else if (this.config.get('core.closeEmptyWindows')) {
      atom.close()
    }
  }

  // Increase the editor font size by 1px.
  increaseFontSize () {
    this.config.set('editor.fontSize', this.config.get('editor.fontSize') + 1)
  }

  // Decrease the editor font size by 1px.
  decreaseFontSize () {
    const fontSize = this.config.get('editor.fontSize')
    if (fontSize > 1) {
      this.config.set('editor.fontSize', fontSize - 1)
    }
  }

  // Restore to the window's original editor font size.
  resetFontSize () {
    if (this.originalFontSize) {
      this.config.set('editor.fontSize', this.originalFontSize)
    }
  }

  subscribeToFontSize () {
    return this.config.onDidChange('editor.fontSize', ({oldValue}) => {
      if (this.originalFontSize == null) {
        this.originalFontSize = oldValue
      }
    })
  }

  // Removes the item's uri from the list of potential items to reopen.
  itemOpened (item) {
    let uri
    if (typeof item.getURI === 'function') {
      uri = item.getURI()
    } else if (typeof item.getUri === 'function') {
      uri = item.getUri()
    }

    if (uri != null) {
      _.remove(this.destroyedItemURIs, uri)
    }
  }

  // Adds the destroyed item's uri to the list of items to reopen.
  didDestroyPaneItem ({item}) {
    let uri
    if (typeof item.getURI === 'function') {
      uri = item.getURI()
    } else if (typeof item.getUri === 'function') {
      uri = item.getUri()
    }

    if (uri != null) {
      this.destroyedItemURIs.push(uri)
    }
  }

  // Called by Model superclass when destroyed
  destroyed () {
    this.paneContainer.destroy()
    if (this.activeItemSubscriptions != null) {
      this.activeItemSubscriptions.dispose()
    }
  }

  /*
  Section: Pane Locations
  */

  getCenter () {
    return this.center
  }

  getLeftDock () {
    return this.docks.left
  }

  getRightDock () {
    return this.docks.right
  }

  getBottomDock () {
    return this.docks.bottom
  }

  getPaneContainers () {
    return [this.getCenter(), ..._.values(this.docks)]
  }

  /*
  Section: Panels

  Panels are used to display UI related to an editor window. They are placed at one of the four
  edges of the window: left, right, top or bottom. If there are multiple panels on the same window
  edge they are stacked in order of priority: higher priority is closer to the center, lower
  priority towards the edge.

  *Note:* If your panel changes its size throughout its lifetime, consider giving it a higher
  priority, allowing fixed size panels to be closer to the edge. This allows control targets to
  remain more static for easier targeting by users that employ mice or trackpads. (See
  [atom/atom#4834](https://github.com/atom/atom/issues/4834) for discussion.)
  */

  // Essential: Get an {Array} of all the panel items at the bottom of the editor window.
  getBottomPanels () {
    return this.getPanels('bottom')
  }

  // Essential: Adds a panel item to the bottom of the editor window.
  //
  // * `options` {Object}
  //   * `item` Your panel content. It can be DOM element, a jQuery element, or
  //     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  //     latter. See {ViewRegistry::addViewProvider} for more information.
  //   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  //     (default: true)
  //   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  //     forced closer to the edges of the window. (default: 100)
  //
  // Returns a {Panel}
  addBottomPanel (options) {
    return this.addPanel('bottom', options)
  }

  // Essential: Get an {Array} of all the panel items to the left of the editor window.
  getLeftPanels () {
    return this.getPanels('left')
  }

  // Essential: Adds a panel item to the left of the editor window.
  //
  // * `options` {Object}
  //   * `item` Your panel content. It can be DOM element, a jQuery element, or
  //     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  //     latter. See {ViewRegistry::addViewProvider} for more information.
  //   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  //     (default: true)
  //   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  //     forced closer to the edges of the window. (default: 100)
  //
  // Returns a {Panel}
  addLeftPanel (options) {
    return this.addPanel('left', options)
  }

  // Essential: Get an {Array} of all the panel items to the right of the editor window.
  getRightPanels () {
    return this.getPanels('right')
  }

  // Essential: Adds a panel item to the right of the editor window.
  //
  // * `options` {Object}
  //   * `item` Your panel content. It can be DOM element, a jQuery element, or
  //     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  //     latter. See {ViewRegistry::addViewProvider} for more information.
  //   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  //     (default: true)
  //   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  //     forced closer to the edges of the window. (default: 100)
  //
  // Returns a {Panel}
  addRightPanel (options) {
    return this.addPanel('right', options)
  }

  // Essential: Get an {Array} of all the panel items at the top of the editor window.
  getTopPanels () {
    return this.getPanels('top')
  }

  // Essential: Adds a panel item to the top of the editor window above the tabs.
  //
  // * `options` {Object}
  //   * `item` Your panel content. It can be DOM element, a jQuery element, or
  //     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  //     latter. See {ViewRegistry::addViewProvider} for more information.
  //   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  //     (default: true)
  //   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  //     forced closer to the edges of the window. (default: 100)
  //
  // Returns a {Panel}
  addTopPanel (options) {
    return this.addPanel('top', options)
  }

  // Essential: Get an {Array} of all the panel items in the header.
  getHeaderPanels () {
    return this.getPanels('header')
  }

  // Essential: Adds a panel item to the header.
  //
  // * `options` {Object}
  //   * `item` Your panel content. It can be DOM element, a jQuery element, or
  //     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  //     latter. See {ViewRegistry::addViewProvider} for more information.
  //   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  //     (default: true)
  //   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  //     forced closer to the edges of the window. (default: 100)
  //
  // Returns a {Panel}
  addHeaderPanel (options) {
    return this.addPanel('header', options)
  }

  // Essential: Get an {Array} of all the panel items in the footer.
  getFooterPanels () {
    return this.getPanels('footer')
  }

  // Essential: Adds a panel item to the footer.
  //
  // * `options` {Object}
  //   * `item` Your panel content. It can be DOM element, a jQuery element, or
  //     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  //     latter. See {ViewRegistry::addViewProvider} for more information.
  //   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  //     (default: true)
  //   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  //     forced closer to the edges of the window. (default: 100)
  //
  // Returns a {Panel}
  addFooterPanel (options) {
    return this.addPanel('footer', options)
  }

  // Essential: Get an {Array} of all the modal panel items
  getModalPanels () {
    return this.getPanels('modal')
  }

  // Essential: Adds a panel item as a modal dialog.
  //
  // * `options` {Object}
  //   * `item` Your panel content. It can be a DOM element, a jQuery element, or
  //     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  //     model option. See {ViewRegistry::addViewProvider} for more information.
  //   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  //     (default: true)
  //   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  //     forced closer to the edges of the window. (default: 100)
  //
  // Returns a {Panel}
  addModalPanel (options = {}) {
    return this.addPanel('modal', options)
  }

  // Essential: Returns the {Panel} associated with the given item. Returns
  // `null` when the item has no panel.
  //
  // * `item` Item the panel contains
  panelForItem (item) {
    for (let location in this.panelContainers) {
      const container = this.panelContainers[location]
      const panel = container.panelForItem(item)
      if (panel != null) { return panel }
    }
    return null
  }

  getPanels (location) {
    return this.panelContainers[location].getPanels()
  }

  addPanel (location, options) {
    if (options == null) { options = {} }
    return this.panelContainers[location].addPanel(new Panel(options, this.viewRegistry))
  }

  /*
  Section: Searching and Replacing
  */

  // Public: Performs a search across all files in the workspace.
  //
  // * `regex` {RegExp} to search with.
  // * `options` (optional) {Object}
  //   * `paths` An {Array} of glob patterns to search within.
  //   * `onPathsSearched` (optional) {Function} to be periodically called
  //     with number of paths searched.
  //   * `leadingContextLineCount` {Number} default `0`; The number of lines
  //      before the matched line to include in the results object.
  //   * `trailingContextLineCount` {Number} default `0`; The number of lines
  //      after the matched line to include in the results object.
  // * `iterator` {Function} callback on each file found.
  //
  // Returns a {Promise} with a `cancel()` method that will cancel all
  // of the underlying searches that were started as part of this scan.
  scan (regex, options = {}, iterator) {
    if (_.isFunction(options)) {
      iterator = options
      options = {}
    }

    // Find a searcher for every Directory in the project. Each searcher that is matched
    // will be associated with an Array of Directory objects in the Map.
    const directoriesForSearcher = new Map()
    for (const directory of this.project.getDirectories()) {
      let searcher = this.defaultDirectorySearcher
      for (const directorySearcher of this.directorySearchers) {
        if (directorySearcher.canSearchDirectory(directory)) {
          searcher = directorySearcher
          break
        }
      }
      let directories = directoriesForSearcher.get(searcher)
      if (!directories) {
        directories = []
        directoriesForSearcher.set(searcher, directories)
      }
      directories.push(directory)
    }

    // Define the onPathsSearched callback.
    let onPathsSearched
    if (_.isFunction(options.onPathsSearched)) {
      // Maintain a map of directories to the number of search results. When notified of a new count,
      // replace the entry in the map and update the total.
      const onPathsSearchedOption = options.onPathsSearched
      let totalNumberOfPathsSearched = 0
      const numberOfPathsSearchedForSearcher = new Map()
      onPathsSearched = function (searcher, numberOfPathsSearched) {
        const oldValue = numberOfPathsSearchedForSearcher.get(searcher)
        if (oldValue) {
          totalNumberOfPathsSearched -= oldValue
        }
        numberOfPathsSearchedForSearcher.set(searcher, numberOfPathsSearched)
        totalNumberOfPathsSearched += numberOfPathsSearched
        return onPathsSearchedOption(totalNumberOfPathsSearched)
      }
    } else {
      onPathsSearched = function () {}
    }

    // Kick off all of the searches and unify them into one Promise.
    const allSearches = []
    directoriesForSearcher.forEach((directories, searcher) => {
      const searchOptions = {
        inclusions: options.paths || [],
        includeHidden: true,
        excludeVcsIgnores: this.config.get('core.excludeVcsIgnoredPaths'),
        exclusions: this.config.get('core.ignoredNames'),
        follow: this.config.get('core.followSymlinks'),
        leadingContextLineCount: options.leadingContextLineCount || 0,
        trailingContextLineCount: options.trailingContextLineCount || 0,
        didMatch: result => {
          if (!this.project.isPathModified(result.filePath)) {
            return iterator(result)
          }
        },
        didError (error) {
          return iterator(null, error)
        },
        didSearchPaths (count) {
          return onPathsSearched(searcher, count)
        }
      }
      const directorySearcher = searcher.search(directories, regex, searchOptions)
      allSearches.push(directorySearcher)
    })
    const searchPromise = Promise.all(allSearches)

    for (let buffer of this.project.getBuffers()) {
      if (buffer.isModified()) {
        const filePath = buffer.getPath()
        if (!this.project.contains(filePath)) {
          continue
        }
        var matches = []
        buffer.scan(regex, match => matches.push(match))
        if (matches.length > 0) {
          iterator({filePath, matches})
        }
      }
    }

    // Make sure the Promise that is returned to the client is cancelable. To be consistent
    // with the existing behavior, instead of cancel() rejecting the promise, it should
    // resolve it with the special value 'cancelled'. At least the built-in find-and-replace
    // package relies on this behavior.
    let isCancelled = false
    const cancellablePromise = new Promise((resolve, reject) => {
      const onSuccess = function () {
        if (isCancelled) {
          resolve('cancelled')
        } else {
          resolve(null)
        }
      }

      const onFailure = function () {
        for (let promise of allSearches) { promise.cancel() }
        reject()
      }

      searchPromise.then(onSuccess, onFailure)
    })
    cancellablePromise.cancel = () => {
      isCancelled = true
      // Note that cancelling all of the members of allSearches will cause all of the searches
      // to resolve, which causes searchPromise to resolve, which is ultimately what causes
      // cancellablePromise to resolve.
      allSearches.map((promise) => promise.cancel())
    }

    // Although this method claims to return a `Promise`, the `ResultsPaneView.onSearch()`
    // method in the find-and-replace package expects the object returned by this method to have a
    // `done()` method. Include a done() method until find-and-replace can be updated.
    cancellablePromise.done = onSuccessOrFailure => {
      cancellablePromise.then(onSuccessOrFailure, onSuccessOrFailure)
    }
    return cancellablePromise
  }

  // Public: Performs a replace across all the specified files in the project.
  //
  // * `regex` A {RegExp} to search with.
  // * `replacementText` {String} to replace all matches of regex with.
  // * `filePaths` An {Array} of file path strings to run the replace on.
  // * `iterator` A {Function} callback on each file with replacements:
  //   * `options` {Object} with keys `filePath` and `replacements`.
  //
  // Returns a {Promise}.
  replace (regex, replacementText, filePaths, iterator) {
    return new Promise((resolve, reject) => {
      let buffer
      const openPaths = this.project.getBuffers().map(buffer => buffer.getPath())
      const outOfProcessPaths = _.difference(filePaths, openPaths)

      let inProcessFinished = !openPaths.length
      let outOfProcessFinished = !outOfProcessPaths.length
      const checkFinished = () => {
        if (outOfProcessFinished && inProcessFinished) {
          resolve()
        }
      }

      if (!outOfProcessFinished.length) {
        let flags = 'g'
        if (regex.ignoreCase) { flags += 'i' }

        const task = Task.once(
          require.resolve('./replace-handler'),
          outOfProcessPaths,
          regex.source,
          flags,
          replacementText,
          () => {
            outOfProcessFinished = true
            checkFinished()
          }
        )

        task.on('replace:path-replaced', iterator)
        task.on('replace:file-error', error => { iterator(null, error) })
      }

      for (buffer of this.project.getBuffers()) {
        if (!filePaths.includes(buffer.getPath())) { continue }
        const replacements = buffer.replace(regex, replacementText, iterator)
        if (replacements) {
          iterator({filePath: buffer.getPath(), replacements})
        }
      }

      inProcessFinished = true
      checkFinished()
    })
  }

  checkoutHeadRevision (editor) {
    if (editor.getPath()) {
      const checkoutHead = () => {
        return this.project.repositoryForDirectory(new Directory(editor.getDirectoryPath()))
          .then(repository => repository != null ? repository.checkoutHeadForEditor(editor) : undefined)
      }

      if (this.config.get('editor.confirmCheckoutHeadRevision')) {
        this.applicationDelegate.confirm({
          message: 'Confirm Checkout HEAD Revision',
          detailedMessage: `Are you sure you want to discard all changes to "${editor.getFileName()}" since the last Git commit?`,
          buttons: {
            OK: checkoutHead,
            Cancel: null
          }
        })
      } else {
        return checkoutHead()
      }
    } else {
      return Promise.resolve(false)
    }
  }
}

const ALL_LOCATIONS = ['center', 'left', 'right', 'bottom']
