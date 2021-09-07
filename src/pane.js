const Grim = require('grim');
const { CompositeDisposable, Emitter } = require('event-kit');
const PaneAxis = require('./pane-axis');
const TextEditor = require('./text-editor');
const { createPaneElement } = require('./pane-element');

let nextInstanceId = 1;

class SaveCancelledError extends Error {}

// Extended: A container for presenting content in the center of the workspace.
// Panes can contain multiple items, one of which is *active* at a given time.
// The view corresponding to the active item is displayed in the interface. In
// the default configuration, tabs are also displayed for each item.
//
// Each pane may also contain one *pending* item. When a pending item is added
// to a pane, it will replace the currently pending item, if any, instead of
// simply being added. In the default configuration, the text in the tab for
// pending items is shown in italics.
module.exports = class Pane {
  inspect() {
    return `Pane ${this.id}`;
  }

  static deserialize(
    state,
    { deserializers, applicationDelegate, config, notifications, views }
  ) {
    const { activeItemIndex } = state;
    const activeItemURI = state.activeItemURI || state.activeItemUri;

    const items = [];
    for (const itemState of state.items) {
      const item = deserializers.deserialize(itemState);
      if (item) items.push(item);
    }
    state.items = items;

    state.activeItem = items[activeItemIndex];
    if (!state.activeItem && activeItemURI) {
      state.activeItem = state.items.find(
        item =>
          typeof item.getURI === 'function' && item.getURI() === activeItemURI
      );
    }

    return new Pane(
      Object.assign(
        {
          deserializerManager: deserializers,
          notificationManager: notifications,
          viewRegistry: views,
          config,
          applicationDelegate
        },
        state
      )
    );
  }

  constructor(params = {}) {
    this.setPendingItem = this.setPendingItem.bind(this);
    this.getPendingItem = this.getPendingItem.bind(this);
    this.clearPendingItem = this.clearPendingItem.bind(this);
    this.onItemDidTerminatePendingState = this.onItemDidTerminatePendingState.bind(
      this
    );
    this.saveItem = this.saveItem.bind(this);
    this.saveItemAs = this.saveItemAs.bind(this);

    this.id = params.id;
    if (this.id != null) {
      nextInstanceId = Math.max(nextInstanceId, this.id + 1);
    } else {
      this.id = nextInstanceId++;
    }

    this.activeItem = params.activeItem;
    this.focused = params.focused != null ? params.focused : false;
    this.applicationDelegate = params.applicationDelegate;
    this.notificationManager = params.notificationManager;
    this.config = params.config;
    this.deserializerManager = params.deserializerManager;
    this.viewRegistry = params.viewRegistry;

    this.emitter = new Emitter();
    this.alive = true;
    this.subscriptionsPerItem = new WeakMap();
    this.items = [];
    this.itemStack = [];
    this.container = null;

    this.addItems((params.items || []).filter(item => item));
    if (!this.getActiveItem()) this.setActiveItem(this.items[0]);
    this.addItemsToStack(params.itemStackIndices || []);
    this.setFlexScale(params.flexScale || 1);
  }

  getElement() {
    if (!this.element) {
      this.element = createPaneElement().initialize(this, {
        views: this.viewRegistry,
        applicationDelegate: this.applicationDelegate
      });
    }
    return this.element;
  }

  serialize() {
    const itemsToBeSerialized = this.items.filter(
      item => item && typeof item.serialize === 'function'
    );

    const itemStackIndices = [];
    for (const item of this.itemStack) {
      if (typeof item.serialize === 'function') {
        itemStackIndices.push(itemsToBeSerialized.indexOf(item));
      }
    }

    const activeItemIndex = itemsToBeSerialized.indexOf(this.activeItem);

    return {
      deserializer: 'Pane',
      id: this.id,
      items: itemsToBeSerialized.map(item => item.serialize()),
      itemStackIndices,
      activeItemIndex,
      focused: this.focused,
      flexScale: this.flexScale
    };
  }

  getParent() {
    return this.parent;
  }

  setParent(parent) {
    this.parent = parent;
  }

  getContainer() {
    return this.container;
  }

  setContainer(container) {
    if (container && container !== this.container) {
      this.container = container;
      container.didAddPane({ pane: this });
    }
  }

  // Private: Determine whether the given item is allowed to exist in this pane.
  //
  // * `item` the Item
  //
  // Returns a {Boolean}.
  isItemAllowed(item) {
    if (typeof item.getAllowedLocations !== 'function') {
      return true;
    } else {
      return item
        .getAllowedLocations()
        .includes(this.getContainer().getLocation());
    }
  }

  setFlexScale(flexScale) {
    this.flexScale = flexScale;
    this.emitter.emit('did-change-flex-scale', this.flexScale);
    return this.flexScale;
  }

  getFlexScale() {
    return this.flexScale;
  }

  increaseSize() {
    if (this.getContainer().getPanes().length > 1) {
      this.setFlexScale(this.getFlexScale() * 1.1);
    }
  }

  decreaseSize() {
    if (this.getContainer().getPanes().length > 1) {
      this.setFlexScale(this.getFlexScale() / 1.1);
    }
  }

  /*
  Section: Event Subscription
  */

  // Public: Invoke the given callback when the pane resizes
  //
  // The callback will be invoked when pane's flexScale property changes.
  // Use {::getFlexScale} to get the current value.
  //
  // * `callback` {Function} to be called when the pane is resized
  //   * `flexScale` {Number} representing the panes `flex-grow`; ability for a
  //     flex item to grow if necessary.
  //
  // Returns a {Disposable} on which '.dispose()' can be called to unsubscribe.
  onDidChangeFlexScale(callback) {
    return this.emitter.on('did-change-flex-scale', callback);
  }

  // Public: Invoke the given callback with the current and future values of
  // {::getFlexScale}.
  //
  // * `callback` {Function} to be called with the current and future values of
  //   the {::getFlexScale} property.
  //   * `flexScale` {Number} representing the panes `flex-grow`; ability for a
  //     flex item to grow if necessary.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeFlexScale(callback) {
    callback(this.flexScale);
    return this.onDidChangeFlexScale(callback);
  }

  // Public: Invoke the given callback when the pane is activated.
  //
  // The given callback will be invoked whenever {::activate} is called on the
  // pane, even if it is already active at the time.
  //
  // * `callback` {Function} to be called when the pane is activated.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidActivate(callback) {
    return this.emitter.on('did-activate', callback);
  }

  // Public: Invoke the given callback before the pane is destroyed.
  //
  // * `callback` {Function} to be called before the pane is destroyed.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillDestroy(callback) {
    return this.emitter.on('will-destroy', callback);
  }

  // Public: Invoke the given callback when the pane is destroyed.
  //
  // * `callback` {Function} to be called when the pane is destroyed.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy(callback) {
    return this.emitter.once('did-destroy', callback);
  }

  // Public: Invoke the given callback when the value of the {::isActive}
  // property changes.
  //
  // * `callback` {Function} to be called when the value of the {::isActive}
  //   property changes.
  //   * `active` {Boolean} indicating whether the pane is active.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActive(callback) {
    return this.container.onDidChangeActivePane(activePane => {
      const isActive = this === activePane;
      callback(isActive);
    });
  }

  // Public: Invoke the given callback with the current and future values of the
  // {::isActive} property.
  //
  // * `callback` {Function} to be called with the current and future values of
  //   the {::isActive} property.
  //   * `active` {Boolean} indicating whether the pane is active.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActive(callback) {
    callback(this.isActive());
    return this.onDidChangeActive(callback);
  }

  // Public: Invoke the given callback when an item is added to the pane.
  //
  // * `callback` {Function} to be called with when items are added.
  //   * `event` {Object} with the following keys:
  //     * `item` The added pane item.
  //     * `index` {Number} indicating where the item is located.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddItem(callback) {
    return this.emitter.on('did-add-item', callback);
  }

  // Public: Invoke the given callback when an item is removed from the pane.
  //
  // * `callback` {Function} to be called with when items are removed.
  //   * `event` {Object} with the following keys:
  //     * `item` The removed pane item.
  //     * `index` {Number} indicating where the item was located.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidRemoveItem(callback) {
    return this.emitter.on('did-remove-item', callback);
  }

  // Public: Invoke the given callback before an item is removed from the pane.
  //
  // * `callback` {Function} to be called with when items are removed.
  //   * `event` {Object} with the following keys:
  //     * `item` The pane item to be removed.
  //     * `index` {Number} indicating where the item is located.
  onWillRemoveItem(callback) {
    return this.emitter.on('will-remove-item', callback);
  }

  // Public: Invoke the given callback when an item is moved within the pane.
  //
  // * `callback` {Function} to be called with when items are moved.
  //   * `event` {Object} with the following keys:
  //     * `item` The removed pane item.
  //     * `oldIndex` {Number} indicating where the item was located.
  //     * `newIndex` {Number} indicating where the item is now located.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidMoveItem(callback) {
    return this.emitter.on('did-move-item', callback);
  }

  // Public: Invoke the given callback with all current and future items.
  //
  // * `callback` {Function} to be called with current and future items.
  //   * `item` An item that is present in {::getItems} at the time of
  //     subscription or that is added at some later time.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeItems(callback) {
    for (let item of this.getItems()) {
      callback(item);
    }
    return this.onDidAddItem(({ item }) => callback(item));
  }

  // Public: Invoke the given callback when the value of {::getActiveItem}
  // changes.
  //
  // * `callback` {Function} to be called with when the active item changes.
  //   * `activeItem` The current active item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActiveItem(callback) {
    return this.emitter.on('did-change-active-item', callback);
  }

  // Public: Invoke the given callback when {::activateNextRecentlyUsedItem}
  // has been called, either initiating or continuing a forward MRU traversal of
  // pane items.
  //
  // * `callback` {Function} to be called with when the active item changes.
  //   * `nextRecentlyUsedItem` The next MRU item, now being set active
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onChooseNextMRUItem(callback) {
    return this.emitter.on('choose-next-mru-item', callback);
  }

  // Public: Invoke the given callback when {::activatePreviousRecentlyUsedItem}
  // has been called, either initiating or continuing a reverse MRU traversal of
  // pane items.
  //
  // * `callback` {Function} to be called with when the active item changes.
  //   * `previousRecentlyUsedItem` The previous MRU item, now being set active
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onChooseLastMRUItem(callback) {
    return this.emitter.on('choose-last-mru-item', callback);
  }

  // Public: Invoke the given callback when {::moveActiveItemToTopOfStack}
  // has been called, terminating an MRU traversal of pane items and moving the
  // current active item to the top of the stack. Typically bound to a modifier
  // (e.g. CTRL) key up event.
  //
  // * `callback` {Function} to be called with when the MRU traversal is done.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDoneChoosingMRUItem(callback) {
    return this.emitter.on('done-choosing-mru-item', callback);
  }

  // Public: Invoke the given callback with the current and future values of
  // {::getActiveItem}.
  //
  // * `callback` {Function} to be called with the current and future active
  //   items.
  //   * `activeItem` The current active item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActiveItem(callback) {
    callback(this.getActiveItem());
    return this.onDidChangeActiveItem(callback);
  }

  // Public: Invoke the given callback before items are destroyed.
  //
  // * `callback` {Function} to be called before items are destroyed.
  //   * `event` {Object} with the following keys:
  //     * `item` The item that will be destroyed.
  //     * `index` The location of the item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to
  // unsubscribe.
  onWillDestroyItem(callback) {
    return this.emitter.on('will-destroy-item', callback);
  }

  // Called by the view layer to indicate that the pane has gained focus.
  focus() {
    return this.activate();
  }

  // Called by the view layer to indicate that the pane has lost focus.
  blur() {
    this.focused = false;
    return true; // if this is called from an event handler, don't cancel it
  }

  isFocused() {
    return this.focused;
  }

  getPanes() {
    return [this];
  }

  unsubscribeFromItem(item) {
    const subscription = this.subscriptionsPerItem.get(item);
    if (subscription) {
      subscription.dispose();
      this.subscriptionsPerItem.delete(item);
    }
  }

  /*
  Section: Items
  */

  // Public: Get the items in this pane.
  //
  // Returns an {Array} of items.
  getItems() {
    return this.items.slice();
  }

  // Public: Get the active pane item in this pane.
  //
  // Returns a pane item.
  getActiveItem() {
    return this.activeItem;
  }

  setActiveItem(activeItem, options) {
    const modifyStack = options && options.modifyStack;
    if (activeItem !== this.activeItem) {
      if (modifyStack !== false) this.addItemToStack(activeItem);
      this.activeItem = activeItem;
      this.emitter.emit('did-change-active-item', this.activeItem);
      if (this.container)
        this.container.didChangeActiveItemOnPane(this, this.activeItem);
    }
    return this.activeItem;
  }

  // Build the itemStack after deserializing
  addItemsToStack(itemStackIndices) {
    if (this.items.length > 0) {
      if (
        itemStackIndices.length !== this.items.length ||
        itemStackIndices.includes(-1)
      ) {
        itemStackIndices = this.items.map((item, i) => i);
      }

      for (let itemIndex of itemStackIndices) {
        this.addItemToStack(this.items[itemIndex]);
      }
    }
  }

  // Add item (or move item) to the end of the itemStack
  addItemToStack(newItem) {
    if (newItem == null) {
      return;
    }
    const index = this.itemStack.indexOf(newItem);
    if (index !== -1) this.itemStack.splice(index, 1);
    return this.itemStack.push(newItem);
  }

  // Return an {TextEditor} if the pane item is an {TextEditor}, or null otherwise.
  getActiveEditor() {
    if (this.activeItem instanceof TextEditor) return this.activeItem;
  }

  // Public: Return the item at the given index.
  //
  // * `index` {Number}
  //
  // Returns an item or `null` if no item exists at the given index.
  itemAtIndex(index) {
    return this.items[index];
  }

  // Makes the next item in the itemStack active.
  activateNextRecentlyUsedItem() {
    if (this.items.length > 1) {
      if (this.itemStackIndex == null)
        this.itemStackIndex = this.itemStack.length - 1;
      if (this.itemStackIndex === 0)
        this.itemStackIndex = this.itemStack.length;
      this.itemStackIndex--;
      const nextRecentlyUsedItem = this.itemStack[this.itemStackIndex];
      this.emitter.emit('choose-next-mru-item', nextRecentlyUsedItem);
      this.setActiveItem(nextRecentlyUsedItem, { modifyStack: false });
    }
  }

  // Makes the previous item in the itemStack active.
  activatePreviousRecentlyUsedItem() {
    if (this.items.length > 1) {
      if (
        this.itemStackIndex + 1 === this.itemStack.length ||
        this.itemStackIndex == null
      ) {
        this.itemStackIndex = -1;
      }
      this.itemStackIndex++;
      const previousRecentlyUsedItem = this.itemStack[this.itemStackIndex];
      this.emitter.emit('choose-last-mru-item', previousRecentlyUsedItem);
      this.setActiveItem(previousRecentlyUsedItem, { modifyStack: false });
    }
  }

  // Moves the active item to the end of the itemStack once the ctrl key is lifted
  moveActiveItemToTopOfStack() {
    delete this.itemStackIndex;
    this.addItemToStack(this.activeItem);
    this.emitter.emit('done-choosing-mru-item');
  }

  // Public: Makes the next item active.
  activateNextItem() {
    const index = this.getActiveItemIndex();
    if (index < this.items.length - 1) {
      this.activateItemAtIndex(index + 1);
    } else {
      this.activateItemAtIndex(0);
    }
  }

  // Public: Makes the previous item active.
  activatePreviousItem() {
    const index = this.getActiveItemIndex();
    if (index > 0) {
      this.activateItemAtIndex(index - 1);
    } else {
      this.activateItemAtIndex(this.items.length - 1);
    }
  }

  activateLastItem() {
    this.activateItemAtIndex(this.items.length - 1);
  }

  // Public: Move the active tab to the right.
  moveItemRight() {
    const index = this.getActiveItemIndex();
    const rightItemIndex = index + 1;
    if (rightItemIndex <= this.items.length - 1)
      this.moveItem(this.getActiveItem(), rightItemIndex);
  }

  // Public: Move the active tab to the left
  moveItemLeft() {
    const index = this.getActiveItemIndex();
    const leftItemIndex = index - 1;
    if (leftItemIndex >= 0)
      return this.moveItem(this.getActiveItem(), leftItemIndex);
  }

  // Public: Get the index of the active item.
  //
  // Returns a {Number}.
  getActiveItemIndex() {
    return this.items.indexOf(this.activeItem);
  }

  // Public: Activate the item at the given index.
  //
  // * `index` {Number}
  activateItemAtIndex(index) {
    const item = this.itemAtIndex(index) || this.getActiveItem();
    return this.setActiveItem(item);
  }

  // Public: Make the given item *active*, causing it to be displayed by
  // the pane's view.
  //
  // * `item` The item to activate
  // * `options` (optional) {Object}
  //   * `pending` (optional) {Boolean} indicating that the item should be added
  //     in a pending state if it does not yet exist in the pane. Existing pending
  //     items in a pane are replaced with new pending items when they are opened.
  activateItem(item, options = {}) {
    if (item) {
      const index =
        this.getPendingItem() === this.activeItem
          ? this.getActiveItemIndex()
          : this.getActiveItemIndex() + 1;
      this.addItem(item, Object.assign({}, options, { index }));
      this.setActiveItem(item);
    }
  }

  // Public: Add the given item to the pane.
  //
  // * `item` The item to add. It can be a model with an associated view or a
  //   view.
  // * `options` (optional) {Object}
  //   * `index` (optional) {Number} indicating the index at which to add the item.
  //     If omitted, the item is added after the current active item.
  //   * `pending` (optional) {Boolean} indicating that the item should be
  //     added in a pending state. Existing pending items in a pane are replaced with
  //     new pending items when they are opened.
  //
  // Returns the added item.
  addItem(item, options = {}) {
    // Backward compat with old API:
    //   addItem(item, index=@getActiveItemIndex() + 1)
    if (typeof options === 'number') {
      Grim.deprecate(
        `Pane::addItem(item, ${options}) is deprecated in favor of Pane::addItem(item, {index: ${options}})`
      );
      options = { index: options };
    }

    const index =
      options.index != null ? options.index : this.getActiveItemIndex() + 1;
    const moved = options.moved != null ? options.moved : false;
    const pending = options.pending != null ? options.pending : false;

    if (!item || typeof item !== 'object') {
      throw new Error(
        `Pane items must be objects. Attempted to add item ${item}.`
      );
    }

    if (typeof item.isDestroyed === 'function' && item.isDestroyed()) {
      throw new Error(
        `Adding a pane item with URI '${typeof item.getURI === 'function' &&
          item.getURI()}' that has already been destroyed`
      );
    }

    if (this.items.includes(item)) return;

    const itemSubscriptions = new CompositeDisposable();
    this.subscriptionsPerItem.set(item, itemSubscriptions);
    if (typeof item.onDidDestroy === 'function') {
      itemSubscriptions.add(
        item.onDidDestroy(() => this.removeItem(item, false))
      );
    }
    if (typeof item.onDidTerminatePendingState === 'function') {
      itemSubscriptions.add(
        item.onDidTerminatePendingState(() => {
          if (this.getPendingItem() === item) this.clearPendingItem();
        })
      );
    }

    this.items.splice(index, 0, item);
    const lastPendingItem = this.getPendingItem();
    const replacingPendingItem = lastPendingItem != null && !moved;
    if (replacingPendingItem) this.pendingItem = null;
    if (pending) this.setPendingItem(item);

    this.emitter.emit('did-add-item', { item, index, moved });
    if (!moved) {
      if (this.container) this.container.didAddPaneItem(item, this, index);
    }

    if (replacingPendingItem) this.destroyItem(lastPendingItem);
    if (!this.getActiveItem()) this.setActiveItem(item);
    return item;
  }

  setPendingItem(item) {
    if (this.pendingItem !== item) {
      const mostRecentPendingItem = this.pendingItem;
      this.pendingItem = item;
      if (mostRecentPendingItem) {
        this.emitter.emit(
          'item-did-terminate-pending-state',
          mostRecentPendingItem
        );
      }
    }
  }

  getPendingItem() {
    return this.pendingItem || null;
  }

  clearPendingItem() {
    this.setPendingItem(null);
  }

  onItemDidTerminatePendingState(callback) {
    return this.emitter.on('item-did-terminate-pending-state', callback);
  }

  // Public: Add the given items to the pane.
  //
  // * `items` An {Array} of items to add. Items can be views or models with
  //   associated views. Any objects that are already present in the pane's
  //   current items will not be added again.
  // * `index` (optional) {Number} index at which to add the items. If omitted,
  //   the item is #   added after the current active item.
  //
  // Returns an {Array} of added items.
  addItems(items, index = this.getActiveItemIndex() + 1) {
    items = items.filter(item => !this.items.includes(item));
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      this.addItem(item, { index: index + i });
    }
    return items;
  }

  removeItem(item, moved) {
    const index = this.items.indexOf(item);
    if (index === -1) return;
    if (this.getPendingItem() === item) this.pendingItem = null;
    this.removeItemFromStack(item);
    this.emitter.emit('will-remove-item', {
      item,
      index,
      destroyed: !moved,
      moved
    });
    this.unsubscribeFromItem(item);

    if (item === this.activeItem) {
      if (this.items.length === 1) {
        this.setActiveItem(undefined);
      } else if (index === 0) {
        this.activateNextItem();
      } else {
        this.activatePreviousItem();
      }
    }
    this.items.splice(index, 1);
    this.emitter.emit('did-remove-item', {
      item,
      index,
      destroyed: !moved,
      moved
    });
    if (!moved && this.container)
      this.container.didDestroyPaneItem({ item, index, pane: this });
    if (this.items.length === 0 && this.config.get('core.destroyEmptyPanes'))
      this.destroy();
  }

  // Remove the given item from the itemStack.
  //
  // * `item` The item to remove.
  // * `index` {Number} indicating the index to which to remove the item from the itemStack.
  removeItemFromStack(item) {
    const index = this.itemStack.indexOf(item);
    if (index !== -1) this.itemStack.splice(index, 1);
  }

  // Public: Move the given item to the given index.
  //
  // * `item` The item to move.
  // * `index` {Number} indicating the index to which to move the item.
  moveItem(item, newIndex) {
    const oldIndex = this.items.indexOf(item);
    this.items.splice(oldIndex, 1);
    this.items.splice(newIndex, 0, item);
    this.emitter.emit('did-move-item', { item, oldIndex, newIndex });
  }

  // Public: Move the given item to the given index on another pane.
  //
  // * `item` The item to move.
  // * `pane` {Pane} to which to move the item.
  // * `index` {Number} indicating the index to which to move the item in the
  //   given pane.
  moveItemToPane(item, pane, index) {
    this.removeItem(item, true);
    return pane.addItem(item, { index, moved: true });
  }

  // Public: Destroy the active item and activate the next item.
  //
  // Returns a {Promise} that resolves when the item is destroyed.
  destroyActiveItem() {
    return this.destroyItem(this.activeItem);
  }

  // Public: Destroy the given item.
  //
  // If the item is active, the next item will be activated. If the item is the
  // last item, the pane will be destroyed if the `core.destroyEmptyPanes` config
  // setting is `true`.
  //
  // This action can be prevented by onWillDestroyPaneItem callbacks in which
  // case nothing happens.
  //
  // * `item` Item to destroy
  // * `force` (optional) {Boolean} Destroy the item without prompting to save
  //    it, even if the item's `isPermanentDockItem` method returns true.
  //
  // Returns a {Promise} that resolves with a {Boolean} indicating whether or not
  // the item was destroyed.
  async destroyItem(item, force) {
    const index = this.items.indexOf(item);
    if (index === -1) return false;

    if (
      !force &&
      typeof item.isPermanentDockItem === 'function' &&
      item.isPermanentDockItem() &&
      (!this.container || this.container.getLocation() !== 'center')
    ) {
      return false;
    }

    // In the case where there are no `onWillDestroyPaneItem` listeners, preserve the old behavior
    // where `Pane.destroyItem` and callers such as `Pane.close` take effect synchronously.
    if (this.emitter.listenerCountForEventName('will-destroy-item') > 0) {
      await this.emitter.emitAsync('will-destroy-item', { item, index });
    }
    if (
      this.container &&
      this.container.emitter.listenerCountForEventName(
        'will-destroy-pane-item'
      ) > 0
    ) {
      let preventClosing = false;
      await this.container.willDestroyPaneItem({
        item,
        index,
        pane: this,
        prevent: () => {
          preventClosing = true;
        }
      });
      if (preventClosing) return false;
    }

    if (
      !force &&
      typeof item.shouldPromptToSave === 'function' &&
      item.shouldPromptToSave()
    ) {
      if (!(await this.promptToSaveItem(item))) return false;
    }
    this.removeItem(item, false);
    if (typeof item.destroy === 'function') item.destroy();
    return true;
  }

  // Public: Destroy all items.
  destroyItems() {
    return Promise.all(this.getItems().map(item => this.destroyItem(item)));
  }

  // Public: Destroy all items except for the active item.
  destroyInactiveItems() {
    return Promise.all(
      this.getItems()
        .filter(item => item !== this.activeItem)
        .map(item => this.destroyItem(item))
    );
  }

  promptToSaveItem(item, options = {}) {
    return new Promise((resolve, reject) => {
      if (
        typeof item.shouldPromptToSave !== 'function' ||
        !item.shouldPromptToSave(options)
      ) {
        return resolve(true);
      }

      let uri;
      if (typeof item.getURI === 'function') {
        uri = item.getURI();
      } else if (typeof item.getUri === 'function') {
        uri = item.getUri();
      } else {
        return resolve(true);
      }

      const title =
        (typeof item.getTitle === 'function' && item.getTitle()) || uri;

      const saveDialog = (saveButtonText, saveFn, message) => {
        this.applicationDelegate.confirm(
          {
            message,
            detail:
              'Your changes will be lost if you close this item without saving.',
            buttons: [saveButtonText, 'Cancel', "&Don't Save"]
          },
          response => {
            switch (response) {
              case 0:
                return saveFn(item, error => {
                  if (error instanceof SaveCancelledError) {
                    resolve(false);
                  } else if (error) {
                    saveDialog(
                      'Save as',
                      this.saveItemAs,
                      `'${title}' could not be saved.\nError: ${this.getMessageForErrorCode(
                        error.code
                      )}`
                    );
                  } else {
                    resolve(true);
                  }
                });
              case 1:
                return resolve(false);
              case 2:
                return resolve(true);
            }
          }
        );
      };

      saveDialog(
        'Save',
        this.saveItem,
        `'${title}' has changes, do you want to save them?`
      );
    });
  }

  // Public: Save the active item.
  saveActiveItem(nextAction) {
    return this.saveItem(this.getActiveItem(), nextAction);
  }

  // Public: Prompt the user for a location and save the active item with the
  // path they select.
  //
  // * `nextAction` (optional) {Function} which will be called after the item is
  //   successfully saved.
  //
  // Returns a {Promise} that resolves when the save is complete
  saveActiveItemAs(nextAction) {
    return this.saveItemAs(this.getActiveItem(), nextAction);
  }

  // Public: Save the given item.
  //
  // * `item` The item to save.
  // * `nextAction` (optional) {Function} which will be called with no argument
  //   after the item is successfully saved, or with the error if it failed.
  //   The return value will be that of `nextAction` or `undefined` if it was not
  //   provided
  //
  // Returns a {Promise} that resolves when the save is complete
  saveItem(item, nextAction) {
    if (!item) return Promise.resolve();

    let itemURI;
    if (typeof item.getURI === 'function') {
      itemURI = item.getURI();
    } else if (typeof item.getUri === 'function') {
      itemURI = item.getUri();
    }

    if (itemURI != null) {
      if (typeof item.save === 'function') {
        return promisify(() => item.save())
          .then(() => {
            if (nextAction) nextAction();
          })
          .catch(error => {
            if (nextAction) {
              nextAction(error);
            } else {
              this.handleSaveError(error, item);
            }
          });
      } else if (nextAction) {
        nextAction();
        return Promise.resolve();
      }
    } else {
      return this.saveItemAs(item, nextAction);
    }
  }

  // Public: Prompt the user for a location and save the active item with the
  // path they select.
  //
  // * `item` The item to save.
  // * `nextAction` (optional) {Function} which will be called with no argument
  //   after the item is successfully saved, or with the error if it failed.
  //   The return value will be that of `nextAction` or `undefined` if it was not
  //   provided
  async saveItemAs(item, nextAction) {
    if (!item) return;
    if (typeof item.saveAs !== 'function') return;

    const saveOptions =
      typeof item.getSaveDialogOptions === 'function'
        ? item.getSaveDialogOptions()
        : {};

    const itemPath = item.getPath();
    if (itemPath && !saveOptions.defaultPath)
      saveOptions.defaultPath = itemPath;

    let resolveSaveDialogPromise = null;
    const saveDialogPromise = new Promise(resolve => {
      resolveSaveDialogPromise = resolve;
    });
    this.applicationDelegate.showSaveDialog(saveOptions, newItemPath => {
      if (newItemPath) {
        promisify(() => item.saveAs(newItemPath))
          .then(() => {
            if (nextAction) {
              resolveSaveDialogPromise(nextAction());
            } else {
              resolveSaveDialogPromise();
            }
          })
          .catch(error => {
            if (nextAction) {
              resolveSaveDialogPromise(nextAction(error));
            } else {
              this.handleSaveError(error, item);
              resolveSaveDialogPromise();
            }
          });
      } else if (nextAction) {
        resolveSaveDialogPromise(
          nextAction(new SaveCancelledError('Save Cancelled'))
        );
      } else {
        resolveSaveDialogPromise();
      }
    });

    return saveDialogPromise;
  }

  // Public: Save all items.
  saveItems() {
    for (let item of this.getItems()) {
      if (typeof item.isModified === 'function' && item.isModified()) {
        this.saveItem(item);
      }
    }
  }

  // Public: Return the first item that matches the given URI or undefined if
  // none exists.
  //
  // * `uri` {String} containing a URI.
  itemForURI(uri) {
    return this.items.find(item => {
      if (typeof item.getURI === 'function') {
        return item.getURI() === uri;
      } else if (typeof item.getUri === 'function') {
        return item.getUri() === uri;
      }
    });
  }

  // Public: Activate the first item that matches the given URI.
  //
  // * `uri` {String} containing a URI.
  //
  // Returns a {Boolean} indicating whether an item matching the URI was found.
  activateItemForURI(uri) {
    const item = this.itemForURI(uri);
    if (item) {
      this.activateItem(item);
      return true;
    } else {
      return false;
    }
  }

  copyActiveItem() {
    if (this.activeItem && typeof this.activeItem.copy === 'function') {
      return this.activeItem.copy();
    }
  }

  /*
  Section: Lifecycle
  */

  // Public: Determine whether the pane is active.
  //
  // Returns a {Boolean}.
  isActive() {
    return this.container && this.container.getActivePane() === this;
  }

  // Public: Makes this pane the *active* pane, causing it to gain focus.
  activate() {
    if (this.isDestroyed()) throw new Error('Pane has been destroyed');
    this.focused = true;

    if (this.container) this.container.didActivatePane(this);
    this.emitter.emit('did-activate');
  }

  // Public: Close the pane and destroy all its items.
  //
  // If this is the last pane, all the items will be destroyed but the pane
  // itself will not be destroyed.
  destroy() {
    if (
      this.container &&
      this.container.isAlive() &&
      this.container.getPanes().length === 1
    ) {
      return this.destroyItems();
    }

    this.emitter.emit('will-destroy');
    this.alive = false;
    if (this.container) {
      this.container.willDestroyPane({ pane: this });
      if (this.isActive()) this.container.activateNextPane();
    }
    this.emitter.emit('did-destroy');
    this.emitter.dispose();
    for (let item of this.items.slice()) {
      if (typeof item.destroy === 'function') item.destroy();
    }
    if (this.container) this.container.didDestroyPane({ pane: this });
  }

  isAlive() {
    return this.alive;
  }

  // Public: Determine whether this pane has been destroyed.
  //
  // Returns a {Boolean}.
  isDestroyed() {
    return !this.isAlive();
  }

  /*
  Section: Splitting
  */

  // Public: Create a new pane to the left of this pane.
  //
  // * `params` (optional) {Object} with the following keys:
  //   * `items` (optional) {Array} of items to add to the new pane.
  //   * `copyActiveItem` (optional) {Boolean} true will copy the active item into the new split pane
  //
  // Returns the new {Pane}.
  splitLeft(params) {
    return this.split('horizontal', 'before', params);
  }

  // Public: Create a new pane to the right of this pane.
  //
  // * `params` (optional) {Object} with the following keys:
  //   * `items` (optional) {Array} of items to add to the new pane.
  //   * `copyActiveItem` (optional) {Boolean} true will copy the active item into the new split pane
  //
  // Returns the new {Pane}.
  splitRight(params) {
    return this.split('horizontal', 'after', params);
  }

  // Public: Creates a new pane above the receiver.
  //
  // * `params` (optional) {Object} with the following keys:
  //   * `items` (optional) {Array} of items to add to the new pane.
  //   * `copyActiveItem` (optional) {Boolean} true will copy the active item into the new split pane
  //
  // Returns the new {Pane}.
  splitUp(params) {
    return this.split('vertical', 'before', params);
  }

  // Public: Creates a new pane below the receiver.
  //
  // * `params` (optional) {Object} with the following keys:
  //   * `items` (optional) {Array} of items to add to the new pane.
  //   * `copyActiveItem` (optional) {Boolean} true will copy the active item into the new split pane
  //
  // Returns the new {Pane}.
  splitDown(params) {
    return this.split('vertical', 'after', params);
  }

  split(orientation, side, params) {
    if (params && params.copyActiveItem) {
      if (!params.items) params.items = [];
      params.items.push(this.copyActiveItem());
    }

    if (this.parent.orientation !== orientation) {
      this.parent.replaceChild(
        this,
        new PaneAxis(
          {
            container: this.container,
            orientation,
            children: [this],
            flexScale: this.flexScale
          },
          this.viewRegistry
        )
      );
      this.setFlexScale(1);
    }

    const newPane = new Pane(
      Object.assign(
        {
          applicationDelegate: this.applicationDelegate,
          notificationManager: this.notificationManager,
          deserializerManager: this.deserializerManager,
          config: this.config,
          viewRegistry: this.viewRegistry
        },
        params
      )
    );

    switch (side) {
      case 'before':
        this.parent.insertChildBefore(this, newPane);
        break;
      case 'after':
        this.parent.insertChildAfter(this, newPane);
        break;
    }

    if (params && params.moveActiveItem && this.activeItem)
      this.moveItemToPane(this.activeItem, newPane);

    newPane.activate();
    return newPane;
  }

  // If the parent is a horizontal axis, returns its first child if it is a pane;
  // otherwise returns this pane.
  findLeftmostSibling() {
    if (this.parent.orientation === 'horizontal') {
      const [leftmostSibling] = this.parent.children;
      if (leftmostSibling instanceof PaneAxis) {
        return this;
      } else {
        return leftmostSibling;
      }
    } else {
      return this;
    }
  }

  findRightmostSibling() {
    if (this.parent.orientation === 'horizontal') {
      const rightmostSibling = this.parent.children[
        this.parent.children.length - 1
      ];
      if (rightmostSibling instanceof PaneAxis) {
        return this;
      } else {
        return rightmostSibling;
      }
    } else {
      return this;
    }
  }

  // If the parent is a horizontal axis, returns its last child if it is a pane;
  // otherwise returns a new pane created by splitting this pane rightward.
  findOrCreateRightmostSibling() {
    const rightmostSibling = this.findRightmostSibling();
    if (rightmostSibling === this) {
      return this.splitRight();
    } else {
      return rightmostSibling;
    }
  }

  // If the parent is a vertical axis, returns its first child if it is a pane;
  // otherwise returns this pane.
  findTopmostSibling() {
    if (this.parent.orientation === 'vertical') {
      const [topmostSibling] = this.parent.children;
      if (topmostSibling instanceof PaneAxis) {
        return this;
      } else {
        return topmostSibling;
      }
    } else {
      return this;
    }
  }

  findBottommostSibling() {
    if (this.parent.orientation === 'vertical') {
      const bottommostSibling = this.parent.children[
        this.parent.children.length - 1
      ];
      if (bottommostSibling instanceof PaneAxis) {
        return this;
      } else {
        return bottommostSibling;
      }
    } else {
      return this;
    }
  }

  // If the parent is a vertical axis, returns its last child if it is a pane;
  // otherwise returns a new pane created by splitting this pane bottomward.
  findOrCreateBottommostSibling() {
    const bottommostSibling = this.findBottommostSibling();
    if (bottommostSibling === this) {
      return this.splitDown();
    } else {
      return bottommostSibling;
    }
  }

  // Private: Close the pane unless the user cancels the action via a dialog.
  //
  // Returns a {Promise} that resolves once the pane is either closed, or the
  // closing has been cancelled.
  close() {
    return Promise.all(
      this.getItems().map(item => this.promptToSaveItem(item))
    ).then(results => {
      if (!results.includes(false)) return this.destroy();
    });
  }

  handleSaveError(error, item) {
    const itemPath =
      error.path || (typeof item.getPath === 'function' && item.getPath());
    const addWarningWithPath = (message, options) => {
      if (itemPath) message = `${message} '${itemPath}'`;
      this.notificationManager.addWarning(message, options);
    };

    const customMessage = this.getMessageForErrorCode(error.code);
    if (customMessage != null) {
      addWarningWithPath(`Unable to save file: ${customMessage}`);
    } else if (
      error.code === 'EISDIR' ||
      (error.message && error.message.endsWith('is a directory'))
    ) {
      return this.notificationManager.addWarning(
        `Unable to save file: ${error.message}`
      );
    } else if (
      ['EPERM', 'EBUSY', 'UNKNOWN', 'EEXIST', 'ELOOP', 'EAGAIN'].includes(
        error.code
      )
    ) {
      addWarningWithPath('Unable to save file', { detail: error.message });
    } else {
      const errorMatch = /ENOTDIR, not a directory '([^']+)'/.exec(
        error.message
      );
      if (errorMatch) {
        const fileName = errorMatch[1];
        this.notificationManager.addWarning(
          `Unable to save file: A directory in the path '${fileName}' could not be written to`
        );
      } else {
        throw error;
      }
    }
  }

  getMessageForErrorCode(errorCode) {
    switch (errorCode) {
      case 'EACCES':
        return 'Permission denied';
      case 'ECONNRESET':
        return 'Connection reset';
      case 'EINTR':
        return 'Interrupted system call';
      case 'EIO':
        return 'I/O error writing file';
      case 'ENOSPC':
        return 'No space left on device';
      case 'ENOTSUP':
        return 'Operation not supported on socket';
      case 'ENXIO':
        return 'No such device or address';
      case 'EROFS':
        return 'Read-only file system';
      case 'ESPIPE':
        return 'Invalid seek';
      case 'ETIMEDOUT':
        return 'Connection timed out';
    }
  }
};

function promisify(callback) {
  try {
    return Promise.resolve(callback());
  } catch (error) {
    return Promise.reject(error);
  }
}
