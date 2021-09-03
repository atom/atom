const { find } = require('underscore-plus');
const { Emitter, CompositeDisposable } = require('event-kit');
const Pane = require('./pane');
const ItemRegistry = require('./item-registry');
const { createPaneContainerElement } = require('./pane-container-element');

const SERIALIZATION_VERSION = 1;
const STOPPED_CHANGING_ACTIVE_PANE_ITEM_DELAY = 100;

module.exports = class PaneContainer {
  constructor(params) {
    let applicationDelegate, deserializerManager, notificationManager;
    ({
      config: this.config,
      applicationDelegate,
      notificationManager,
      deserializerManager,
      viewRegistry: this.viewRegistry,
      location: this.location
    } = params);
    this.emitter = new Emitter();
    this.subscriptions = new CompositeDisposable();
    this.itemRegistry = new ItemRegistry();
    this.alive = true;
    this.stoppedChangingActivePaneItemTimeout = null;

    this.setRoot(
      new Pane({
        container: this,
        config: this.config,
        applicationDelegate,
        notificationManager,
        deserializerManager,
        viewRegistry: this.viewRegistry
      })
    );
    this.didActivatePane(this.getRoot());
  }

  getLocation() {
    return this.location;
  }

  getElement() {
    return this.element != null
      ? this.element
      : (this.element = createPaneContainerElement().initialize(this, {
          views: this.viewRegistry
        }));
  }

  destroy() {
    this.alive = false;
    for (let pane of this.getRoot().getPanes()) {
      pane.destroy();
    }
    this.cancelStoppedChangingActivePaneItemTimeout();
    this.subscriptions.dispose();
    this.emitter.dispose();
  }

  isAlive() {
    return this.alive;
  }

  isDestroyed() {
    return !this.isAlive();
  }

  serialize(params) {
    return {
      deserializer: 'PaneContainer',
      version: SERIALIZATION_VERSION,
      root: this.root ? this.root.serialize() : null,
      activePaneId: this.activePane.id
    };
  }

  deserialize(state, deserializerManager) {
    if (state.version !== SERIALIZATION_VERSION) return;
    this.itemRegistry = new ItemRegistry();
    this.setRoot(deserializerManager.deserialize(state.root));
    this.activePane =
      find(this.getRoot().getPanes(), pane => pane.id === state.activePaneId) ||
      this.getPanes()[0];
    if (this.config.get('core.destroyEmptyPanes')) this.destroyEmptyPanes();
  }

  onDidChangeRoot(fn) {
    return this.emitter.on('did-change-root', fn);
  }

  observeRoot(fn) {
    fn(this.getRoot());
    return this.onDidChangeRoot(fn);
  }

  onDidAddPane(fn) {
    return this.emitter.on('did-add-pane', fn);
  }

  observePanes(fn) {
    for (let pane of this.getPanes()) {
      fn(pane);
    }
    return this.onDidAddPane(({ pane }) => fn(pane));
  }

  onDidDestroyPane(fn) {
    return this.emitter.on('did-destroy-pane', fn);
  }

  onWillDestroyPane(fn) {
    return this.emitter.on('will-destroy-pane', fn);
  }

  onDidChangeActivePane(fn) {
    return this.emitter.on('did-change-active-pane', fn);
  }

  onDidActivatePane(fn) {
    return this.emitter.on('did-activate-pane', fn);
  }

  observeActivePane(fn) {
    fn(this.getActivePane());
    return this.onDidChangeActivePane(fn);
  }

  onDidAddPaneItem(fn) {
    return this.emitter.on('did-add-pane-item', fn);
  }

  observePaneItems(fn) {
    for (let item of this.getPaneItems()) {
      fn(item);
    }
    return this.onDidAddPaneItem(({ item }) => fn(item));
  }

  onDidChangeActivePaneItem(fn) {
    return this.emitter.on('did-change-active-pane-item', fn);
  }

  onDidStopChangingActivePaneItem(fn) {
    return this.emitter.on('did-stop-changing-active-pane-item', fn);
  }

  observeActivePaneItem(fn) {
    fn(this.getActivePaneItem());
    return this.onDidChangeActivePaneItem(fn);
  }

  onWillDestroyPaneItem(fn) {
    return this.emitter.on('will-destroy-pane-item', fn);
  }

  onDidDestroyPaneItem(fn) {
    return this.emitter.on('did-destroy-pane-item', fn);
  }

  getRoot() {
    return this.root;
  }

  setRoot(root) {
    this.root = root;
    this.root.setParent(this);
    this.root.setContainer(this);
    this.emitter.emit('did-change-root', this.root);
    if (this.getActivePane() == null && this.root instanceof Pane) {
      this.didActivatePane(this.root);
    }
  }

  replaceChild(oldChild, newChild) {
    if (oldChild !== this.root) {
      throw new Error('Replacing non-existent child');
    }
    this.setRoot(newChild);
  }

  getPanes() {
    if (this.alive) {
      return this.getRoot().getPanes();
    } else {
      return [];
    }
  }

  getPaneItems() {
    return this.getRoot().getItems();
  }

  getActivePane() {
    return this.activePane;
  }

  getActivePaneItem() {
    return this.getActivePane().getActiveItem();
  }

  paneForURI(uri) {
    return find(this.getPanes(), pane => pane.itemForURI(uri) != null);
  }

  paneForItem(item) {
    return find(this.getPanes(), pane => pane.getItems().includes(item));
  }

  saveAll() {
    for (let pane of this.getPanes()) {
      pane.saveItems();
    }
  }

  confirmClose(options) {
    const promises = [];
    for (const pane of this.getPanes()) {
      for (const item of pane.getItems()) {
        promises.push(pane.promptToSaveItem(item, options));
      }
    }
    return Promise.all(promises).then(results => !results.includes(false));
  }

  activateNextPane() {
    const panes = this.getPanes();
    if (panes.length > 1) {
      const currentIndex = panes.indexOf(this.activePane);
      const nextIndex = (currentIndex + 1) % panes.length;
      panes[nextIndex].activate();
      return true;
    } else {
      return false;
    }
  }

  activatePreviousPane() {
    const panes = this.getPanes();
    if (panes.length > 1) {
      const currentIndex = panes.indexOf(this.activePane);
      let previousIndex = currentIndex - 1;
      if (previousIndex < 0) {
        previousIndex = panes.length - 1;
      }
      panes[previousIndex].activate();
      return true;
    } else {
      return false;
    }
  }

  moveActiveItemToPane(destPane) {
    const item = this.activePane.getActiveItem();

    if (!destPane.isItemAllowed(item)) {
      return;
    }

    this.activePane.moveItemToPane(item, destPane);
    destPane.setActiveItem(item);
  }

  copyActiveItemToPane(destPane) {
    const item = this.activePane.copyActiveItem();

    if (item && destPane.isItemAllowed(item)) {
      destPane.activateItem(item);
    }
  }

  destroyEmptyPanes() {
    for (let pane of this.getPanes()) {
      if (pane.items.length === 0) {
        pane.destroy();
      }
    }
  }

  didAddPane(event) {
    this.emitter.emit('did-add-pane', event);
    const items = event.pane.getItems();
    for (let i = 0, length = items.length; i < length; i++) {
      const item = items[i];
      this.didAddPaneItem(item, event.pane, i);
    }
  }

  willDestroyPane(event) {
    this.emitter.emit('will-destroy-pane', event);
  }

  didDestroyPane(event) {
    this.emitter.emit('did-destroy-pane', event);
  }

  didActivatePane(activePane) {
    if (activePane !== this.activePane) {
      if (!this.getPanes().includes(activePane)) {
        throw new Error(
          'Setting active pane that is not present in pane container'
        );
      }

      this.activePane = activePane;
      this.emitter.emit('did-change-active-pane', this.activePane);
      this.didChangeActiveItemOnPane(
        this.activePane,
        this.activePane.getActiveItem()
      );
    }
    this.emitter.emit('did-activate-pane', this.activePane);
    return this.activePane;
  }

  didAddPaneItem(item, pane, index) {
    this.itemRegistry.addItem(item);
    this.emitter.emit('did-add-pane-item', { item, pane, index });
  }

  willDestroyPaneItem(event) {
    return this.emitter.emitAsync('will-destroy-pane-item', event);
  }

  didDestroyPaneItem(event) {
    this.itemRegistry.removeItem(event.item);
    this.emitter.emit('did-destroy-pane-item', event);
  }

  didChangeActiveItemOnPane(pane, activeItem) {
    if (pane === this.getActivePane()) {
      this.emitter.emit('did-change-active-pane-item', activeItem);

      this.cancelStoppedChangingActivePaneItemTimeout();
      // `setTimeout()` isn't available during the snapshotting phase, but that's okay.
      if (!global.isGeneratingSnapshot) {
        this.stoppedChangingActivePaneItemTimeout = setTimeout(() => {
          this.stoppedChangingActivePaneItemTimeout = null;
          this.emitter.emit('did-stop-changing-active-pane-item', activeItem);
        }, STOPPED_CHANGING_ACTIVE_PANE_ITEM_DELAY);
      }
    }
  }

  cancelStoppedChangingActivePaneItemTimeout() {
    if (this.stoppedChangingActivePaneItemTimeout != null) {
      clearTimeout(this.stoppedChangingActivePaneItemTimeout);
    }
  }
};
