const { extend } = require('underscore-plus');
const { Emitter } = require('event-kit');
const Grim = require('grim');
const Pane = require('../src/pane');
const PaneContainer = require('../src/pane-container');
const { conditionPromise, timeoutPromise } = require('./async-spec-helpers');

describe('Pane', () => {
  let confirm, showSaveDialog, deserializerDisposable;

  class Item {
    static deserialize({ name, uri }) {
      return new Item(name, uri);
    }

    constructor(name, uri) {
      this.name = name;
      this.uri = uri;
      this.emitter = new Emitter();
      this.destroyed = false;
    }

    getURI() {
      return this.uri;
    }
    getPath() {
      return this.path;
    }
    isEqual(other) {
      return this.name === (other && other.name);
    }
    isPermanentDockItem() {
      return false;
    }
    isDestroyed() {
      return this.destroyed;
    }

    serialize() {
      return { deserializer: 'Item', name: this.name, uri: this.uri };
    }

    copy() {
      return new Item(this.name, this.uri);
    }

    destroy() {
      this.destroyed = true;
      return this.emitter.emit('did-destroy');
    }

    onDidDestroy(fn) {
      return this.emitter.on('did-destroy', fn);
    }

    onDidTerminatePendingState(callback) {
      return this.emitter.on('terminate-pending-state', callback);
    }

    terminatePendingState() {
      return this.emitter.emit('terminate-pending-state');
    }
  }

  beforeEach(() => {
    confirm = spyOn(atom.applicationDelegate, 'confirm');
    showSaveDialog = spyOn(atom.applicationDelegate, 'showSaveDialog');
    deserializerDisposable = atom.deserializers.add(Item);
  });

  afterEach(() => {
    deserializerDisposable.dispose();
  });

  function paneParams(params) {
    return extend(
      {
        applicationDelegate: atom.applicationDelegate,
        config: atom.config,
        deserializerManager: atom.deserializers,
        notificationManager: atom.notifications
      },
      params
    );
  }

  describe('construction', () => {
    it('sets the active item to the first item', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B')] })
      );
      expect(pane.getActiveItem()).toBe(pane.itemAtIndex(0));
    });

    it('compacts the items array', () => {
      const pane = new Pane(
        paneParams({ items: [undefined, new Item('A'), null, new Item('B')] })
      );
      expect(pane.getItems().length).toBe(2);
      expect(pane.getActiveItem()).toBe(pane.itemAtIndex(0));
    });
  });

  describe('::activate()', () => {
    let container, pane1, pane2;

    beforeEach(() => {
      container = new PaneContainer({
        location: 'center',
        config: atom.config,
        applicationDelegate: atom.applicationDelegate
      });
      container.getActivePane().splitRight();
      [pane1, pane2] = container.getPanes();
    });

    it('changes the active pane on the container', () => {
      expect(container.getActivePane()).toBe(pane2);
      pane1.activate();
      expect(container.getActivePane()).toBe(pane1);
      pane2.activate();
      expect(container.getActivePane()).toBe(pane2);
    });

    it('invokes ::onDidChangeActivePane observers on the container', () => {
      const observed = [];
      container.onDidChangeActivePane(activePane => observed.push(activePane));

      pane1.activate();
      pane1.activate();
      pane2.activate();
      pane1.activate();
      expect(observed).toEqual([pane1, pane2, pane1]);
    });

    it('invokes ::onDidChangeActive observers on the relevant panes', () => {
      const observed = [];
      pane1.onDidChangeActive(active => observed.push(active));
      pane1.activate();
      pane2.activate();
      expect(observed).toEqual([true, false]);
    });

    it('invokes ::onDidActivate() observers', () => {
      let eventCount = 0;
      pane1.onDidActivate(() => eventCount++);
      pane1.activate();
      pane1.activate();
      pane2.activate();
      expect(eventCount).toBe(2);
    });
  });

  describe('::addItem(item, index)', () => {
    it('adds the item at the given index', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B')] })
      );
      const [item1, item2] = pane.getItems();
      const item3 = new Item('C');
      pane.addItem(item3, { index: 1 });
      expect(pane.getItems()).toEqual([item1, item3, item2]);
    });

    it('adds the item after the active item if no index is provided', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B'), new Item('C')] })
      );
      const [item1, item2, item3] = pane.getItems();
      pane.activateItem(item2);
      const item4 = new Item('D');
      pane.addItem(item4);
      expect(pane.getItems()).toEqual([item1, item2, item4, item3]);
    });

    it('sets the active item after adding the first item', () => {
      const pane = new Pane(paneParams());
      const item = new Item('A');
      pane.addItem(item);
      expect(pane.getActiveItem()).toBe(item);
    });

    it('invokes ::onDidAddItem() observers', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B')] })
      );
      const events = [];
      pane.onDidAddItem(event => events.push(event));

      const item = new Item('C');
      pane.addItem(item, { index: 1 });
      expect(events).toEqual([{ item, index: 1, moved: false }]);
    });

    it('throws an exception if the item is already present on a pane', () => {
      const item = new Item('A');
      const container = new PaneContainer({
        config: atom.config,
        applicationDelegate: atom.applicationDelegate
      });
      const pane1 = container.getActivePane();
      pane1.addItem(item);
      const pane2 = pane1.splitRight();
      expect(() => pane2.addItem(item)).toThrow();
    });

    it("throws an exception if the item isn't an object", () => {
      const pane = new Pane(paneParams({ items: [] }));
      expect(() => pane.addItem(null)).toThrow();
      expect(() => pane.addItem('foo')).toThrow();
      expect(() => pane.addItem(1)).toThrow();
    });

    it('destroys any existing pending item', () => {
      const pane = new Pane(paneParams({ items: [] }));
      const itemA = new Item('A');
      const itemB = new Item('B');
      const itemC = new Item('C');
      pane.addItem(itemA, { pending: false });
      pane.addItem(itemB, { pending: true });
      pane.addItem(itemC, { pending: false });
      expect(itemB.isDestroyed()).toBe(true);
    });

    it('adds the new item before destroying any existing pending item', () => {
      const eventOrder = [];

      const pane = new Pane(paneParams({ items: [] }));
      const itemA = new Item('A');
      const itemB = new Item('B');
      pane.addItem(itemA, { pending: true });

      pane.onDidAddItem(function({ item }) {
        if (item === itemB) eventOrder.push('add');
      });

      pane.onDidRemoveItem(function({ item }) {
        if (item === itemA) eventOrder.push('remove');
      });

      pane.addItem(itemB);

      waitsFor(() => eventOrder.length === 2);

      runs(() => expect(eventOrder).toEqual(['add', 'remove']));
    });

    it('subscribes to be notified when item terminates its pending state', () => {
      const fakeDisposable = { dispose: () => {} };
      const spy = jasmine
        .createSpy('onDidTerminatePendingState')
        .andReturn(fakeDisposable);

      const pane = new Pane(paneParams({ items: [] }));
      const item = {
        getTitle: () => '',
        onDidTerminatePendingState: spy
      };
      pane.addItem(item);

      expect(spy).toHaveBeenCalled();
    });

    it('subscribes to be notified when item is destroyed', () => {
      const fakeDisposable = { dispose: () => {} };
      const spy = jasmine.createSpy('onDidDestroy').andReturn(fakeDisposable);

      const pane = new Pane(paneParams({ items: [] }));
      const item = {
        getTitle: () => '',
        onDidDestroy: spy
      };
      pane.addItem(item);

      expect(spy).toHaveBeenCalled();
    });

    describe('when using the old API of ::addItem(item, index)', () => {
      beforeEach(() => spyOn(Grim, 'deprecate'));

      it('supports the older public API', () => {
        const pane = new Pane(paneParams({ items: [] }));
        const itemA = new Item('A');
        const itemB = new Item('B');
        const itemC = new Item('C');
        pane.addItem(itemA, 0);
        pane.addItem(itemB, 0);
        pane.addItem(itemC, 0);
        expect(pane.getItems()).toEqual([itemC, itemB, itemA]);
      });

      it('shows a deprecation warning', () => {
        const pane = new Pane(paneParams({ items: [] }));
        pane.addItem(new Item(), 2);
        expect(Grim.deprecate).toHaveBeenCalledWith(
          'Pane::addItem(item, 2) is deprecated in favor of Pane::addItem(item, {index: 2})'
        );
      });
    });
  });

  describe('::activateItem(item)', () => {
    let pane = null;

    beforeEach(() => {
      pane = new Pane(paneParams({ items: [new Item('A'), new Item('B')] }));
    });

    it('changes the active item to the current item', () => {
      expect(pane.getActiveItem()).toBe(pane.itemAtIndex(0));
      pane.activateItem(pane.itemAtIndex(1));
      expect(pane.getActiveItem()).toBe(pane.itemAtIndex(1));
    });

    it("adds the given item if it isn't present in ::items", () => {
      const item = new Item('C');
      pane.activateItem(item);
      expect(pane.getItems().includes(item)).toBe(true);
      expect(pane.getActiveItem()).toBe(item);
    });

    it('invokes ::onDidChangeActiveItem() observers', () => {
      const observed = [];
      pane.onDidChangeActiveItem(item => observed.push(item));
      pane.activateItem(pane.itemAtIndex(1));
      expect(observed).toEqual([pane.itemAtIndex(1)]);
    });

    describe('when the item being activated is pending', () => {
      let itemC = null;
      let itemD = null;

      beforeEach(() => {
        itemC = new Item('C');
        itemD = new Item('D');
      });

      it('replaces the active item if it is pending', () => {
        pane.activateItem(itemC, { pending: true });
        expect(pane.getItems().map(item => item.name)).toEqual(['A', 'C', 'B']);
        pane.activateItem(itemD, { pending: true });
        expect(pane.getItems().map(item => item.name)).toEqual(['A', 'D', 'B']);
      });

      it('adds the item after the active item if it is not pending', () => {
        pane.activateItem(itemC, { pending: true });
        pane.activateItemAtIndex(2);
        pane.activateItem(itemD, { pending: true });
        expect(pane.getItems().map(item => item.name)).toEqual(['A', 'B', 'D']);
      });
    });
  });

  describe('::setPendingItem', () => {
    let pane = null;

    beforeEach(() => {
      pane = atom.workspace.getActivePane();
    });

    it('changes the pending item', () => {
      expect(pane.getPendingItem()).toBeNull();
      pane.setPendingItem('fake item');
      expect(pane.getPendingItem()).toEqual('fake item');
    });
  });

  describe('::onItemDidTerminatePendingState callback', () => {
    let pane = null;
    let callbackCalled = false;

    beforeEach(() => {
      pane = atom.workspace.getActivePane();
      callbackCalled = false;
    });

    it('is called when the pending item changes', () => {
      pane.setPendingItem('fake item one');
      pane.onItemDidTerminatePendingState(function(item) {
        callbackCalled = true;
        expect(item).toEqual('fake item one');
      });
      pane.setPendingItem('fake item two');
      expect(callbackCalled).toBeTruthy();
    });

    it('has access to the new pending item via ::getPendingItem', () => {
      pane.setPendingItem('fake item one');
      pane.onItemDidTerminatePendingState(function(item) {
        callbackCalled = true;
        expect(pane.getPendingItem()).toEqual('fake item two');
      });
      pane.setPendingItem('fake item two');
      expect(callbackCalled).toBeTruthy();
    });

    it("isn't called when a pending item is replaced with a new one", async () => {
      pane = null;
      const pendingSpy = jasmine.createSpy('onItemDidTerminatePendingState');
      const destroySpy = jasmine.createSpy('onWillDestroyItem');

      await atom.workspace.open('sample.txt', { pending: true });
      pane = atom.workspace.getActivePane();

      pane.onItemDidTerminatePendingState(pendingSpy);
      pane.onWillDestroyItem(destroySpy);

      await atom.workspace.open('sample.js', { pending: true });

      expect(destroySpy).toHaveBeenCalled();
      expect(pendingSpy).not.toHaveBeenCalled();
    });
  });

  describe('::activateNextRecentlyUsedItem() and ::activatePreviousRecentlyUsedItem()', () => {
    it('sets the active item to the next/previous item in the itemStack, looping around at either end', () => {
      const pane = new Pane(
        paneParams({
          items: [
            new Item('A'),
            new Item('B'),
            new Item('C'),
            new Item('D'),
            new Item('E')
          ]
        })
      );
      const [item1, item2, item3, item4, item5] = pane.getItems();
      pane.itemStack = [item3, item1, item2, item5, item4];

      pane.activateItem(item4);
      expect(pane.getActiveItem()).toBe(item4);
      pane.activateNextRecentlyUsedItem();
      expect(pane.getActiveItem()).toBe(item5);
      pane.activateNextRecentlyUsedItem();
      expect(pane.getActiveItem()).toBe(item2);
      pane.activatePreviousRecentlyUsedItem();
      expect(pane.getActiveItem()).toBe(item5);
      pane.activatePreviousRecentlyUsedItem();
      expect(pane.getActiveItem()).toBe(item4);
      pane.activatePreviousRecentlyUsedItem();
      expect(pane.getActiveItem()).toBe(item3);
      pane.activatePreviousRecentlyUsedItem();
      expect(pane.getActiveItem()).toBe(item1);
      pane.activateNextRecentlyUsedItem();
      expect(pane.getActiveItem()).toBe(item3);
      pane.activateNextRecentlyUsedItem();
      expect(pane.getActiveItem()).toBe(item4);
      pane.activateNextRecentlyUsedItem();
      pane.moveActiveItemToTopOfStack();
      expect(pane.getActiveItem()).toBe(item5);
      expect(pane.itemStack[4]).toBe(item5);
    });
  });

  describe('::activateNextItem() and ::activatePreviousItem()', () => {
    it('sets the active item to the next/previous item, looping around at either end', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B'), new Item('C')] })
      );
      const [item1, item2, item3] = pane.getItems();

      expect(pane.getActiveItem()).toBe(item1);
      pane.activatePreviousItem();
      expect(pane.getActiveItem()).toBe(item3);
      pane.activatePreviousItem();
      expect(pane.getActiveItem()).toBe(item2);
      pane.activateNextItem();
      expect(pane.getActiveItem()).toBe(item3);
      pane.activateNextItem();
      expect(pane.getActiveItem()).toBe(item1);
    });
  });

  describe('::activateLastItem()', () => {
    it('sets the active item to the last item', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B'), new Item('C')] })
      );
      const [item1, , item3] = pane.getItems();

      expect(pane.getActiveItem()).toBe(item1);
      pane.activateLastItem();
      expect(pane.getActiveItem()).toBe(item3);
    });
  });

  describe('::moveItemRight() and ::moveItemLeft()', () => {
    it('moves the active item to the right and left, without looping around at either end', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B'), new Item('C')] })
      );
      const [item1, item2, item3] = pane.getItems();

      pane.activateItemAtIndex(0);
      expect(pane.getActiveItem()).toBe(item1);
      pane.moveItemLeft();
      expect(pane.getItems()).toEqual([item1, item2, item3]);
      pane.moveItemRight();
      expect(pane.getItems()).toEqual([item2, item1, item3]);
      pane.moveItemLeft();
      expect(pane.getItems()).toEqual([item1, item2, item3]);
      pane.activateItemAtIndex(2);
      expect(pane.getActiveItem()).toBe(item3);
      pane.moveItemRight();
      expect(pane.getItems()).toEqual([item1, item2, item3]);
    });
  });

  describe('::activateItemAtIndex(index)', () => {
    it('activates the item at the given index', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B'), new Item('C')] })
      );
      const [item1, item2, item3] = pane.getItems();
      pane.activateItemAtIndex(2);
      expect(pane.getActiveItem()).toBe(item3);
      pane.activateItemAtIndex(1);
      expect(pane.getActiveItem()).toBe(item2);
      pane.activateItemAtIndex(0);
      expect(pane.getActiveItem()).toBe(item1);

      // Doesn't fail with out-of-bounds indices
      pane.activateItemAtIndex(100);
      expect(pane.getActiveItem()).toBe(item1);
      pane.activateItemAtIndex(-1);
      expect(pane.getActiveItem()).toBe(item1);
    });
  });

  describe('::destroyItem(item)', () => {
    let pane, item1, item2, item3;

    beforeEach(() => {
      pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B'), new Item('C')] })
      );
      [item1, item2, item3] = pane.getItems();
    });

    it('removes the item from the items list and destroys it', () => {
      expect(pane.getActiveItem()).toBe(item1);
      pane.destroyItem(item2);
      expect(pane.getItems().includes(item2)).toBe(false);
      expect(item2.isDestroyed()).toBe(true);
      expect(pane.getActiveItem()).toBe(item1);

      pane.destroyItem(item1);
      expect(pane.getItems().includes(item1)).toBe(false);
      expect(item1.isDestroyed()).toBe(true);
    });

    it('removes the item from the itemStack', () => {
      pane.itemStack = [item2, item3, item1];

      pane.activateItem(item1);
      expect(pane.getActiveItem()).toBe(item1);
      pane.destroyItem(item3);
      expect(pane.itemStack).toEqual([item2, item1]);
      expect(pane.getActiveItem()).toBe(item1);

      pane.destroyItem(item1);
      expect(pane.itemStack).toEqual([item2]);
      expect(pane.getActiveItem()).toBe(item2);

      pane.destroyItem(item2);
      expect(pane.itemStack).toEqual([]);
      expect(pane.getActiveItem()).toBeUndefined();
    });

    it('does nothing if prevented', () => {
      const container = new PaneContainer({
        config: atom.config,
        deserializerManager: atom.deserializers,
        applicationDelegate: atom.applicationDelegate
      });

      pane.setContainer(container);
      container.onWillDestroyPaneItem(e => e.prevent());
      pane.itemStack = [item2, item3, item1];

      pane.activateItem(item1);
      expect(pane.getActiveItem()).toBe(item1);
      pane.destroyItem(item3);
      expect(pane.itemStack).toEqual([item2, item3, item1]);
      expect(pane.getActiveItem()).toBe(item1);

      pane.destroyItem(item1);
      expect(pane.itemStack).toEqual([item2, item3, item1]);
      expect(pane.getActiveItem()).toBe(item1);

      pane.destroyItem(item2);
      expect(pane.itemStack).toEqual([item2, item3, item1]);
      expect(pane.getActiveItem()).toBe(item1);
    });

    it('invokes ::onWillDestroyItem() and PaneContainer::onWillDestroyPaneItem observers before destroying the item', async () => {
      jasmine.useRealClock();
      pane.container = new PaneContainer({ config: atom.config, confirm });
      const events = [];

      pane.onWillDestroyItem(async event => {
        expect(item2.isDestroyed()).toBe(false);
        await timeoutPromise(50);
        expect(item2.isDestroyed()).toBe(false);
        events.push(['will-destroy-item', event]);
      });

      pane.container.onWillDestroyPaneItem(async event => {
        expect(item2.isDestroyed()).toBe(false);
        await timeoutPromise(50);
        expect(item2.isDestroyed()).toBe(false);
        events.push(['will-destroy-pane-item', event]);
      });

      await pane.destroyItem(item2);
      expect(item2.isDestroyed()).toBe(true);

      expect(events[0][0]).toEqual('will-destroy-item');
      expect(events[0][1].item).toEqual(item2);
      expect(events[0][1].index).toEqual(1);

      expect(events[1][0]).toEqual('will-destroy-pane-item');
      expect(events[1][1].item).toEqual(item2);
      expect(events[1][1].index).toEqual(1);
      expect(typeof events[1][1].prevent).toEqual('function');
      expect(events[1][1].pane).toEqual(pane);
    });

    it('invokes ::onWillRemoveItem() observers', () => {
      const events = [];
      pane.onWillRemoveItem(event => events.push(event));
      pane.destroyItem(item2);
      expect(events).toEqual([
        { item: item2, index: 1, moved: false, destroyed: true }
      ]);
    });

    it('invokes ::onDidRemoveItem() observers', () => {
      const events = [];
      pane.onDidRemoveItem(event => events.push(event));
      pane.destroyItem(item2);
      expect(events).toEqual([
        { item: item2, index: 1, moved: false, destroyed: true }
      ]);
    });

    describe('when the destroyed item is the active item and is the first item', () => {
      it('activates the next item', () => {
        expect(pane.getActiveItem()).toBe(item1);
        pane.destroyItem(item1);
        expect(pane.getActiveItem()).toBe(item2);
      });
    });

    describe('when the destroyed item is the active item and is not the first item', () => {
      beforeEach(() => pane.activateItem(item2));

      it('activates the previous item', () => {
        expect(pane.getActiveItem()).toBe(item2);
        pane.destroyItem(item2);
        expect(pane.getActiveItem()).toBe(item1);
      });
    });

    describe('if the item is modified', () => {
      let itemURI = null;

      beforeEach(() => {
        item1.shouldPromptToSave = () => true;
        item1.save = jasmine.createSpy('save');
        item1.saveAs = jasmine.createSpy('saveAs');
        item1.getURI = () => itemURI;
      });

      describe('if the [Save] option is selected', () => {
        describe('when the item has a uri', () => {
          it('saves the item before destroying it', async () => {
            itemURI = 'test';
            confirm.andCallFake((options, callback) => callback(0));

            const success = await pane.destroyItem(item1);
            expect(item1.save).toHaveBeenCalled();
            expect(pane.getItems().includes(item1)).toBe(false);
            expect(item1.isDestroyed()).toBe(true);
            expect(success).toBe(true);
          });
        });

        describe('when the item has no uri', () => {
          it('presents a save-as dialog, then saves the item with the given uri before removing and destroying it', async () => {
            jasmine.useRealClock();

            itemURI = null;

            showSaveDialog.andCallFake((options, callback) =>
              callback('/selected/path')
            );
            confirm.andCallFake((options, callback) => callback(0));

            const success = await pane.destroyItem(item1);
            expect(showSaveDialog.mostRecentCall.args[0]).toEqual({});

            await conditionPromise(() => item1.saveAs.callCount === 1);
            expect(item1.saveAs).toHaveBeenCalledWith('/selected/path');
            expect(pane.getItems().includes(item1)).toBe(false);
            expect(item1.isDestroyed()).toBe(true);
            expect(success).toBe(true);
          });
        });
      });

      describe("if the [Don't Save] option is selected", () => {
        it('removes and destroys the item without saving it', async () => {
          confirm.andCallFake((options, callback) => callback(2));

          const success = await pane.destroyItem(item1);
          expect(item1.save).not.toHaveBeenCalled();
          expect(pane.getItems().includes(item1)).toBe(false);
          expect(item1.isDestroyed()).toBe(true);
          expect(success).toBe(true);
        });
      });

      describe('if the [Cancel] option is selected', () => {
        it('does not save, remove, or destroy the item', async () => {
          confirm.andCallFake((options, callback) => callback(1));

          const success = await pane.destroyItem(item1);
          expect(item1.save).not.toHaveBeenCalled();
          expect(pane.getItems().includes(item1)).toBe(true);
          expect(item1.isDestroyed()).toBe(false);
          expect(success).toBe(false);
        });
      });

      describe('when force=true', () => {
        it('destroys the item immediately', async () => {
          const success = await pane.destroyItem(item1, true);
          expect(item1.save).not.toHaveBeenCalled();
          expect(pane.getItems().includes(item1)).toBe(false);
          expect(item1.isDestroyed()).toBe(true);
          expect(success).toBe(true);
        });
      });
    });

    describe('when the last item is destroyed', () => {
      describe("when the 'core.destroyEmptyPanes' config option is false (the default)", () => {
        it('does not destroy the pane, but leaves it in place with empty items', () => {
          expect(atom.config.get('core.destroyEmptyPanes')).toBe(false);
          for (let item of pane.getItems()) {
            pane.destroyItem(item);
          }
          expect(pane.isDestroyed()).toBe(false);
          expect(pane.getActiveItem()).toBeUndefined();
          expect(() => pane.saveActiveItem()).not.toThrow();
          expect(() => pane.saveActiveItemAs()).not.toThrow();
        });
      });

      describe("when the 'core.destroyEmptyPanes' config option is true", () => {
        it('destroys the pane', () => {
          atom.config.set('core.destroyEmptyPanes', true);
          for (let item of pane.getItems()) {
            pane.destroyItem(item);
          }
          expect(pane.isDestroyed()).toBe(true);
        });
      });
    });

    describe('when passed a permanent dock item', () => {
      it("doesn't destroy the item", async () => {
        spyOn(item1, 'isPermanentDockItem').andReturn(true);
        const success = await pane.destroyItem(item1);
        expect(pane.getItems().includes(item1)).toBe(true);
        expect(item1.isDestroyed()).toBe(false);
        expect(success).toBe(false);
      });

      it('destroy the item if force=true', async () => {
        spyOn(item1, 'isPermanentDockItem').andReturn(true);
        const success = await pane.destroyItem(item1, true);
        expect(pane.getItems().includes(item1)).toBe(false);
        expect(item1.isDestroyed()).toBe(true);
        expect(success).toBe(true);
      });
    });
  });

  describe('::destroyActiveItem()', () => {
    it('destroys the active item', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B')] })
      );
      const activeItem = pane.getActiveItem();
      pane.destroyActiveItem();
      expect(activeItem.isDestroyed()).toBe(true);
      expect(pane.getItems().includes(activeItem)).toBe(false);
    });

    it('does not throw an exception if there are no more items', () => {
      const pane = new Pane(paneParams());
      pane.destroyActiveItem();
    });
  });

  describe('::destroyItems()', () => {
    it('destroys all items', async () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B'), new Item('C')] })
      );
      const [item1, item2, item3] = pane.getItems();

      await pane.destroyItems();
      expect(item1.isDestroyed()).toBe(true);
      expect(item2.isDestroyed()).toBe(true);
      expect(item3.isDestroyed()).toBe(true);
      expect(pane.getItems()).toEqual([]);
    });
  });

  describe('::observeItems()', () => {
    it('invokes the observer with all current and future items', () => {
      const pane = new Pane(paneParams({ items: [new Item(), new Item()] }));
      const [item1, item2] = pane.getItems();

      const observed = [];
      pane.observeItems(item => observed.push(item));

      const item3 = new Item();
      pane.addItem(item3);

      expect(observed).toEqual([item1, item2, item3]);
    });
  });

  describe('when an item emits a destroyed event', () => {
    it('removes it from the list of items', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B'), new Item('C')] })
      );
      const [item1, , item3] = pane.getItems();
      pane.itemAtIndex(1).destroy();
      expect(pane.getItems()).toEqual([item1, item3]);
    });
  });

  describe('::destroyInactiveItems()', () => {
    it('destroys all items but the active item', () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B'), new Item('C')] })
      );
      const [, item2] = pane.getItems();
      pane.activateItem(item2);
      pane.destroyInactiveItems();
      expect(pane.getItems()).toEqual([item2]);
    });
  });

  describe('::saveActiveItem()', () => {
    let pane;

    beforeEach(() => {
      pane = new Pane(paneParams({ items: [new Item('A')] }));
      showSaveDialog.andCallFake((options, callback) =>
        callback('/selected/path')
      );
    });

    describe('when the active item has a uri', () => {
      beforeEach(() => {
        pane.getActiveItem().uri = 'test';
      });

      describe('when the active item has a save method', () => {
        it('saves the current item', () => {
          pane.getActiveItem().save = jasmine.createSpy('save');
          pane.saveActiveItem();
          expect(pane.getActiveItem().save).toHaveBeenCalled();
        });
      });

      describe('when the current item has no save method', () => {
        it('does nothing', () => {
          expect(pane.getActiveItem().save).toBeUndefined();
          pane.saveActiveItem();
        });
      });
    });

    describe('when the current item has no uri', () => {
      describe('when the current item has a saveAs method', () => {
        it('opens a save dialog and saves the current item as the selected path', async () => {
          pane.getActiveItem().saveAs = jasmine.createSpy('saveAs');
          await pane.saveActiveItem();
          expect(showSaveDialog.mostRecentCall.args[0]).toEqual({});
          expect(pane.getActiveItem().saveAs).toHaveBeenCalledWith(
            '/selected/path'
          );
        });
      });

      describe('when the current item has no saveAs method', () => {
        it('does nothing', async () => {
          expect(pane.getActiveItem().saveAs).toBeUndefined();
          await pane.saveActiveItem();
          expect(showSaveDialog).not.toHaveBeenCalled();
        });
      });

      it('does nothing if the user cancels choosing a path', async () => {
        pane.getActiveItem().saveAs = jasmine.createSpy('saveAs');
        showSaveDialog.andCallFake((options, callback) => callback(undefined));
        await pane.saveActiveItem();
        expect(pane.getActiveItem().saveAs).not.toHaveBeenCalled();
      });
    });

    describe("when the item's saveAs rejects with a well-known IO error", () => {
      it('creates a notification', () => {
        pane.getActiveItem().saveAs = () => {
          const error = new Error("EACCES, permission denied '/foo'");
          error.path = '/foo';
          error.code = 'EACCES';
          return Promise.reject(error);
        };

        waitsFor(done => {
          const subscription = atom.notifications.onDidAddNotification(function(
            notification
          ) {
            expect(notification.getType()).toBe('warning');
            expect(notification.getMessage()).toContain('Permission denied');
            expect(notification.getMessage()).toContain('/foo');
            subscription.dispose();
            done();
          });
          pane.saveActiveItem();
        });
      });
    });

    describe("when the item's saveAs throws a well-known IO error", () => {
      it('creates a notification', () => {
        pane.getActiveItem().saveAs = () => {
          const error = new Error("EACCES, permission denied '/foo'");
          error.path = '/foo';
          error.code = 'EACCES';
          throw error;
        };

        waitsFor(done => {
          const subscription = atom.notifications.onDidAddNotification(function(
            notification
          ) {
            expect(notification.getType()).toBe('warning');
            expect(notification.getMessage()).toContain('Permission denied');
            expect(notification.getMessage()).toContain('/foo');
            subscription.dispose();
            done();
          });
          pane.saveActiveItem();
        });
      });
    });
  });

  describe('::saveActiveItemAs()', () => {
    let pane = null;

    beforeEach(() => {
      pane = new Pane(paneParams({ items: [new Item('A')] }));
      showSaveDialog.andCallFake((options, callback) =>
        callback('/selected/path')
      );
    });

    describe('when the current item has a saveAs method', () => {
      it('opens the save dialog and calls saveAs on the item with the selected path', async () => {
        jasmine.useRealClock();

        pane.getActiveItem().path = __filename;
        pane.getActiveItem().saveAs = jasmine.createSpy('saveAs');
        pane.saveActiveItemAs();
        expect(showSaveDialog.mostRecentCall.args[0]).toEqual({
          defaultPath: __filename
        });

        await conditionPromise(
          () => pane.getActiveItem().saveAs.callCount === 1
        );
        expect(pane.getActiveItem().saveAs).toHaveBeenCalledWith(
          '/selected/path'
        );
      });
    });

    describe('when the current item does not have a saveAs method', () => {
      it('does nothing', () => {
        expect(pane.getActiveItem().saveAs).toBeUndefined();
        pane.saveActiveItemAs();
        expect(showSaveDialog).not.toHaveBeenCalled();
      });
    });

    describe("when the item's saveAs method throws a well-known IO error", () => {
      it('creates a notification', () => {
        pane.getActiveItem().saveAs = () => {
          const error = new Error("EACCES, permission denied '/foo'");
          error.path = '/foo';
          error.code = 'EACCES';
          return Promise.reject(error);
        };

        waitsFor(done => {
          const subscription = atom.notifications.onDidAddNotification(function(
            notification
          ) {
            expect(notification.getType()).toBe('warning');
            expect(notification.getMessage()).toContain('Permission denied');
            expect(notification.getMessage()).toContain('/foo');
            subscription.dispose();
            done();
          });
          pane.saveActiveItemAs();
        });
      });
    });
  });

  describe('::itemForURI(uri)', () => {
    it('returns the item for which a call to .getURI() returns the given uri', () => {
      const pane = new Pane(
        paneParams({
          items: [new Item('A'), new Item('B'), new Item('C'), new Item('D')]
        })
      );
      const [item1, item2] = pane.getItems();
      item1.uri = 'a';
      item2.uri = 'b';
      expect(pane.itemForURI('a')).toBe(item1);
      expect(pane.itemForURI('b')).toBe(item2);
      expect(pane.itemForURI('bogus')).toBeUndefined();
    });
  });

  describe('::moveItem(item, index)', () => {
    let pane, item1, item2, item3, item4;

    beforeEach(() => {
      pane = new Pane(
        paneParams({
          items: [new Item('A'), new Item('B'), new Item('C'), new Item('D')]
        })
      );
      [item1, item2, item3, item4] = pane.getItems();
    });

    it('moves the item to the given index and invokes ::onDidMoveItem observers', () => {
      pane.moveItem(item1, 2);
      expect(pane.getItems()).toEqual([item2, item3, item1, item4]);

      pane.moveItem(item2, 3);
      expect(pane.getItems()).toEqual([item3, item1, item4, item2]);

      pane.moveItem(item2, 1);
      expect(pane.getItems()).toEqual([item3, item2, item1, item4]);
    });

    it('invokes ::onDidMoveItem() observers', () => {
      const events = [];
      pane.onDidMoveItem(event => events.push(event));

      pane.moveItem(item1, 2);
      pane.moveItem(item2, 3);
      expect(events).toEqual([
        { item: item1, oldIndex: 0, newIndex: 2 },
        { item: item2, oldIndex: 0, newIndex: 3 }
      ]);
    });
  });

  describe('::moveItemToPane(item, pane, index)', () => {
    let container, pane1, pane2;
    let item1, item2, item3, item4, item5;

    beforeEach(() => {
      container = new PaneContainer({ config: atom.config, confirm });
      pane1 = container.getActivePane();
      pane1.addItems([new Item('A'), new Item('B'), new Item('C')]);
      pane2 = pane1.splitRight({ items: [new Item('D'), new Item('E')] });
      [item1, item2, item3] = pane1.getItems();
      [item4, item5] = pane2.getItems();
    });

    it('moves the item to the given pane at the given index', () => {
      pane1.moveItemToPane(item2, pane2, 1);
      expect(pane1.getItems()).toEqual([item1, item3]);
      expect(pane2.getItems()).toEqual([item4, item2, item5]);
    });

    it('invokes ::onWillRemoveItem() observers', () => {
      const events = [];
      pane1.onWillRemoveItem(event => events.push(event));
      pane1.moveItemToPane(item2, pane2, 1);

      expect(events).toEqual([
        { item: item2, index: 1, moved: true, destroyed: false }
      ]);
    });

    it('invokes ::onDidRemoveItem() observers', () => {
      const events = [];
      pane1.onDidRemoveItem(event => events.push(event));
      pane1.moveItemToPane(item2, pane2, 1);

      expect(events).toEqual([
        { item: item2, index: 1, moved: true, destroyed: false }
      ]);
    });

    it('does not invoke ::onDidAddPaneItem observers on the container', () => {
      const addedItems = [];
      container.onDidAddPaneItem(item => addedItems.push(item));
      pane1.moveItemToPane(item2, pane2, 1);
      expect(addedItems).toEqual([]);
    });

    describe('when the moved item the last item in the source pane', () => {
      beforeEach(() => item5.destroy());

      describe("when the 'core.destroyEmptyPanes' config option is false (the default)", () => {
        it('does not destroy the pane or the item', () => {
          pane2.moveItemToPane(item4, pane1, 0);
          expect(pane2.isDestroyed()).toBe(false);
          expect(item4.isDestroyed()).toBe(false);
        });
      });

      describe("when the 'core.destroyEmptyPanes' config option is true", () => {
        it('destroys the pane, but not the item', () => {
          atom.config.set('core.destroyEmptyPanes', true);
          pane2.moveItemToPane(item4, pane1, 0);
          expect(pane2.isDestroyed()).toBe(true);
          expect(item4.isDestroyed()).toBe(false);
        });
      });
    });

    describe('when the item being moved is pending', () => {
      it('is made permanent in the new pane', () => {
        const item6 = new Item('F');
        pane1.addItem(item6, { pending: true });
        expect(pane1.getPendingItem()).toEqual(item6);
        pane1.moveItemToPane(item6, pane2, 0);
        expect(pane2.getPendingItem()).not.toEqual(item6);
      });
    });

    describe('when the target pane has a pending item', () => {
      it('does not destroy the pending item', () => {
        const item6 = new Item('F');
        pane1.addItem(item6, { pending: true });
        expect(pane1.getPendingItem()).toEqual(item6);
        pane2.moveItemToPane(item5, pane1, 0);
        expect(pane1.getPendingItem()).toEqual(item6);
      });
    });
  });

  describe('split methods', () => {
    let pane1, item1, container;

    beforeEach(() => {
      container = new PaneContainer({
        config: atom.config,
        confirm,
        deserializerManager: atom.deserializers
      });
      pane1 = container.getActivePane();
      item1 = new Item('A');
      pane1.addItem(item1);
    });

    describe('::splitLeft(params)', () => {
      describe('when the parent is the container root', () => {
        it('replaces itself with a row and inserts a new pane to the left of itself', () => {
          const pane2 = pane1.splitLeft({ items: [new Item('B')] });
          const pane3 = pane1.splitLeft({ items: [new Item('C')] });
          expect(container.root.orientation).toBe('horizontal');
          expect(container.root.children).toEqual([pane2, pane3, pane1]);
        });
      });

      describe('when `moveActiveItem: true` is passed in the params', () => {
        it('moves the active item', () => {
          const pane2 = pane1.splitLeft({ moveActiveItem: true });
          expect(pane2.getActiveItem()).toBe(item1);
        });
      });

      describe('when `copyActiveItem: true` is passed in the params', () => {
        it('duplicates the active item', () => {
          const pane2 = pane1.splitLeft({ copyActiveItem: true });
          expect(pane2.getActiveItem()).toEqual(pane1.getActiveItem());
        });

        it("does nothing if the active item doesn't implement .copy()", () => {
          item1.copy = null;
          const pane2 = pane1.splitLeft({ copyActiveItem: true });
          expect(pane2.getActiveItem()).toBeUndefined();
        });
      });

      describe('when the parent is a column', () => {
        it('replaces itself with a row and inserts a new pane to the left of itself', () => {
          pane1.splitDown();
          const pane2 = pane1.splitLeft({ items: [new Item('B')] });
          const pane3 = pane1.splitLeft({ items: [new Item('C')] });
          const row = container.root.children[0];
          expect(row.orientation).toBe('horizontal');
          expect(row.children).toEqual([pane2, pane3, pane1]);
        });
      });
    });

    describe('::splitRight(params)', () => {
      describe('when the parent is the container root', () => {
        it('replaces itself with a row and inserts a new pane to the right of itself', () => {
          const pane2 = pane1.splitRight({ items: [new Item('B')] });
          const pane3 = pane1.splitRight({ items: [new Item('C')] });
          expect(container.root.orientation).toBe('horizontal');
          expect(container.root.children).toEqual([pane1, pane3, pane2]);
        });
      });

      describe('when `moveActiveItem: true` is passed in the params', () => {
        it('moves the active item', () => {
          const pane2 = pane1.splitRight({ moveActiveItem: true });
          expect(pane2.getActiveItem()).toBe(item1);
        });
      });

      describe('when `copyActiveItem: true` is passed in the params', () => {
        it('duplicates the active item', () => {
          const pane2 = pane1.splitRight({ copyActiveItem: true });
          expect(pane2.getActiveItem()).toEqual(pane1.getActiveItem());
        });
      });

      describe('when the parent is a column', () => {
        it('replaces itself with a row and inserts a new pane to the right of itself', () => {
          pane1.splitDown();
          const pane2 = pane1.splitRight({ items: [new Item('B')] });
          const pane3 = pane1.splitRight({ items: [new Item('C')] });
          const row = container.root.children[0];
          expect(row.orientation).toBe('horizontal');
          expect(row.children).toEqual([pane1, pane3, pane2]);
        });
      });
    });

    describe('::splitUp(params)', () => {
      describe('when the parent is the container root', () => {
        it('replaces itself with a column and inserts a new pane above itself', () => {
          const pane2 = pane1.splitUp({ items: [new Item('B')] });
          const pane3 = pane1.splitUp({ items: [new Item('C')] });
          expect(container.root.orientation).toBe('vertical');
          expect(container.root.children).toEqual([pane2, pane3, pane1]);
        });
      });

      describe('when `moveActiveItem: true` is passed in the params', () => {
        it('moves the active item', () => {
          const pane2 = pane1.splitUp({ moveActiveItem: true });
          expect(pane2.getActiveItem()).toBe(item1);
        });
      });

      describe('when `copyActiveItem: true` is passed in the params', () => {
        it('duplicates the active item', () => {
          const pane2 = pane1.splitUp({ copyActiveItem: true });
          expect(pane2.getActiveItem()).toEqual(pane1.getActiveItem());
        });
      });

      describe('when the parent is a row', () => {
        it('replaces itself with a column and inserts a new pane above itself', () => {
          pane1.splitRight();
          const pane2 = pane1.splitUp({ items: [new Item('B')] });
          const pane3 = pane1.splitUp({ items: [new Item('C')] });
          const column = container.root.children[0];
          expect(column.orientation).toBe('vertical');
          expect(column.children).toEqual([pane2, pane3, pane1]);
        });
      });
    });

    describe('::splitDown(params)', () => {
      describe('when the parent is the container root', () => {
        it('replaces itself with a column and inserts a new pane below itself', () => {
          const pane2 = pane1.splitDown({ items: [new Item('B')] });
          const pane3 = pane1.splitDown({ items: [new Item('C')] });
          expect(container.root.orientation).toBe('vertical');
          expect(container.root.children).toEqual([pane1, pane3, pane2]);
        });
      });

      describe('when `moveActiveItem: true` is passed in the params', () => {
        it('moves the active item', () => {
          const pane2 = pane1.splitDown({ moveActiveItem: true });
          expect(pane2.getActiveItem()).toBe(item1);
        });
      });

      describe('when `copyActiveItem: true` is passed in the params', () => {
        it('duplicates the active item', () => {
          const pane2 = pane1.splitDown({ copyActiveItem: true });
          expect(pane2.getActiveItem()).toEqual(pane1.getActiveItem());
        });
      });

      describe('when the parent is a row', () => {
        it('replaces itself with a column and inserts a new pane below itself', () => {
          pane1.splitRight();
          const pane2 = pane1.splitDown({ items: [new Item('B')] });
          const pane3 = pane1.splitDown({ items: [new Item('C')] });
          const column = container.root.children[0];
          expect(column.orientation).toBe('vertical');
          expect(column.children).toEqual([pane1, pane3, pane2]);
        });
      });
    });

    describe('when the pane is empty', () => {
      describe('when `moveActiveItem: true` is passed in the params', () => {
        it('gracefully ignores the moveActiveItem parameter', () => {
          pane1.destroyItem(item1);
          expect(pane1.getActiveItem()).toBe(undefined);

          const pane2 = pane1.split('horizontal', 'before', {
            moveActiveItem: true
          });
          expect(container.root.children).toEqual([pane2, pane1]);

          expect(pane2.getActiveItem()).toBe(undefined);
        });
      });

      describe('when `copyActiveItem: true` is passed in the params', () => {
        it('gracefully ignores the copyActiveItem parameter', () => {
          pane1.destroyItem(item1);
          expect(pane1.getActiveItem()).toBe(undefined);

          const pane2 = pane1.split('horizontal', 'before', {
            copyActiveItem: true
          });
          expect(container.root.children).toEqual([pane2, pane1]);

          expect(pane2.getActiveItem()).toBe(undefined);
        });
      });
    });

    it('activates the new pane', () => {
      expect(pane1.isActive()).toBe(true);
      const pane2 = pane1.splitRight();
      expect(pane1.isActive()).toBe(false);
      expect(pane2.isActive()).toBe(true);
    });
  });

  describe('::close()', () => {
    it('prompts to save unsaved items before destroying the pane', async () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B')] })
      );
      const [item1] = pane.getItems();

      item1.shouldPromptToSave = () => true;
      item1.getURI = () => '/test/path';
      item1.save = jasmine.createSpy('save');

      confirm.andCallFake((options, callback) => callback(0));
      await pane.close();
      expect(confirm).toHaveBeenCalled();
      expect(item1.save).toHaveBeenCalled();
      expect(pane.isDestroyed()).toBe(true);
    });

    it('does not destroy the pane if the user clicks cancel', async () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B')] })
      );
      const [item1] = pane.getItems();

      item1.shouldPromptToSave = () => true;
      item1.getURI = () => '/test/path';
      item1.save = jasmine.createSpy('save');

      confirm.andCallFake((options, callback) => callback(1));

      await pane.close();
      expect(confirm).toHaveBeenCalled();
      expect(item1.save).not.toHaveBeenCalled();
      expect(pane.isDestroyed()).toBe(false);
    });

    it('does not destroy the pane if the user starts to save but then does not choose a path', async () => {
      const pane = new Pane(
        paneParams({ items: [new Item('A'), new Item('B')] })
      );
      const [item1] = pane.getItems();

      item1.shouldPromptToSave = () => true;
      item1.saveAs = jasmine.createSpy('saveAs');

      confirm.andCallFake((options, callback) => callback(0));
      showSaveDialog.andCallFake((options, callback) => callback(undefined));

      await pane.close();
      expect(atom.applicationDelegate.confirm).toHaveBeenCalled();
      expect(confirm.callCount).toBe(1);
      expect(item1.saveAs).not.toHaveBeenCalled();
      expect(pane.isDestroyed()).toBe(false);
    });

    describe('when item fails to save', () => {
      let pane, item1;

      beforeEach(() => {
        pane = new Pane({
          items: [new Item('A'), new Item('B')],
          applicationDelegate: atom.applicationDelegate,
          config: atom.config
        });
        [item1] = pane.getItems();

        item1.shouldPromptToSave = () => true;
        item1.getURI = () => '/test/path';

        item1.save = jasmine.createSpy('save').andCallFake(() => {
          const error = new Error("EACCES, permission denied '/test/path'");
          error.path = '/test/path';
          error.code = 'EACCES';
          throw error;
        });
      });

      it('does not destroy the pane if save fails and user clicks cancel', async () => {
        let confirmations = 0;
        confirm.andCallFake((options, callback) => {
          confirmations++;
          if (confirmations === 1) {
            callback(0); // click save
          } else {
            callback(1);
          }
        }); // click cancel

        await pane.close();
        expect(atom.applicationDelegate.confirm).toHaveBeenCalled();
        expect(confirmations).toBe(2);
        expect(item1.save).toHaveBeenCalled();
        expect(pane.isDestroyed()).toBe(false);
      });

      it('does destroy the pane if the user saves the file under a new name', async () => {
        item1.saveAs = jasmine.createSpy('saveAs').andReturn(true);

        let confirmations = 0;
        confirm.andCallFake((options, callback) => {
          confirmations++;
          callback(0);
        }); // save and then save as

        showSaveDialog.andCallFake((options, callback) => callback('new/path'));

        await pane.close();
        expect(atom.applicationDelegate.confirm).toHaveBeenCalled();
        expect(confirmations).toBe(2);
        expect(
          atom.applicationDelegate.showSaveDialog.mostRecentCall.args[0]
        ).toEqual({});
        expect(item1.save).toHaveBeenCalled();
        expect(item1.saveAs).toHaveBeenCalled();
        expect(pane.isDestroyed()).toBe(true);
      });

      it('asks again if the saveAs also fails', async () => {
        item1.saveAs = jasmine.createSpy('saveAs').andCallFake(() => {
          const error = new Error("EACCES, permission denied '/test/path'");
          error.path = '/test/path';
          error.code = 'EACCES';
          throw error;
        });

        let confirmations = 0;
        confirm.andCallFake((options, callback) => {
          confirmations++;
          if (confirmations < 3) {
            callback(0); // save, save as, save as
          } else {
            callback(2); // don't save
          }
        });

        showSaveDialog.andCallFake((options, callback) => callback('new/path'));

        await pane.close();
        expect(atom.applicationDelegate.confirm).toHaveBeenCalled();
        expect(confirmations).toBe(3);
        expect(
          atom.applicationDelegate.showSaveDialog.mostRecentCall.args[0]
        ).toEqual({});
        expect(item1.save).toHaveBeenCalled();
        expect(item1.saveAs).toHaveBeenCalled();
        expect(pane.isDestroyed()).toBe(true);
      });
    });
  });

  describe('::destroy()', () => {
    let container, pane1, pane2;

    beforeEach(() => {
      container = new PaneContainer({ config: atom.config, confirm });
      pane1 = container.root;
      pane1.addItems([new Item('A'), new Item('B')]);
      pane2 = pane1.splitRight();
    });

    it('invokes ::onWillDestroy observers before destroying items', () => {
      let itemsDestroyed = null;
      pane1.onWillDestroy(() => {
        itemsDestroyed = pane1.getItems().map(item => item.isDestroyed());
      });
      pane1.destroy();
      expect(itemsDestroyed).toEqual([false, false]);
    });

    it("destroys the pane's destroyable items", () => {
      const [item1, item2] = pane1.getItems();
      pane1.destroy();
      expect(item1.isDestroyed()).toBe(true);
      expect(item2.isDestroyed()).toBe(true);
    });

    describe('if the pane is active', () => {
      it('makes the next pane active', () => {
        expect(pane2.isActive()).toBe(true);
        pane2.destroy();
        expect(pane1.isActive()).toBe(true);
      });
    });

    describe("if the pane's parent has more than two children", () => {
      it('removes the pane from its parent', () => {
        const pane3 = pane2.splitRight();

        expect(container.root.children).toEqual([pane1, pane2, pane3]);
        pane2.destroy();
        expect(container.root.children).toEqual([pane1, pane3]);
      });
    });

    describe("if the pane's parent has two children", () => {
      it('replaces the parent with its last remaining child', () => {
        const pane3 = pane2.splitDown();

        expect(container.root.children[0]).toBe(pane1);
        expect(container.root.children[1].children).toEqual([pane2, pane3]);
        pane3.destroy();
        expect(container.root.children).toEqual([pane1, pane2]);
        pane2.destroy();
        expect(container.root).toBe(pane1);
      });
    });
  });

  describe('pending state', () => {
    let editor1, pane, eventCount;

    beforeEach(async () => {
      editor1 = await atom.workspace.open('sample.txt', { pending: true });
      pane = atom.workspace.getActivePane();
      eventCount = 0;
      editor1.onDidTerminatePendingState(() => eventCount++);
    });

    it('does not open file in pending state by default', async () => {
      await atom.workspace.open('sample.js');
      expect(pane.getPendingItem()).toBeNull();
    });

    it("opens file in pending state if 'pending' option is true", () => {
      expect(pane.getPendingItem()).toEqual(editor1);
    });

    it('terminates pending state if ::terminatePendingState is invoked', () => {
      editor1.terminatePendingState();

      expect(pane.getPendingItem()).toBeNull();
      expect(eventCount).toBe(1);
    });

    it('terminates pending state when buffer is changed', () => {
      editor1.insertText("I'll be back!");
      advanceClock(editor1.getBuffer().stoppedChangingDelay);

      expect(pane.getPendingItem()).toBeNull();
      expect(eventCount).toBe(1);
    });

    it('only calls terminate handler once when text is modified twice', async () => {
      const originalText = editor1.getText();
      editor1.insertText('Some text');
      advanceClock(editor1.getBuffer().stoppedChangingDelay);

      await editor1.save();

      editor1.insertText('More text');
      advanceClock(editor1.getBuffer().stoppedChangingDelay);

      expect(pane.getPendingItem()).toBeNull();
      expect(eventCount).toBe(1);

      // Reset fixture back to original state
      editor1.setText(originalText);
      await editor1.save();
    });

    it('only calls clearPendingItem if there is a pending item to clear', () => {
      spyOn(pane, 'clearPendingItem').andCallThrough();

      editor1.terminatePendingState();
      editor1.terminatePendingState();

      expect(pane.getPendingItem()).toBeNull();
      expect(pane.clearPendingItem.callCount).toBe(1);
    });
  });

  describe('serialization', () => {
    let pane = null;

    beforeEach(() => {
      pane = new Pane(
        paneParams({
          items: [new Item('A', 'a'), new Item('B', 'b'), new Item('C', 'c')],
          flexScale: 2
        })
      );
    });

    it('can serialize and deserialize the pane and all its items', () => {
      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.getItems()).toEqual(pane.getItems());
    });

    it('restores the active item on deserialization', () => {
      pane.activateItemAtIndex(1);
      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.getActiveItem()).toEqual(newPane.itemAtIndex(1));
    });

    it("restores the active item when it doesn't implement getURI()", () => {
      pane.items[1].getURI = null;
      pane.activateItemAtIndex(1);
      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.getActiveItem()).toEqual(newPane.itemAtIndex(1));
    });

    it("restores the correct item when it doesn't implement getURI() and some items weren't deserialized", () => {
      const unserializable = {};
      pane.addItem(unserializable, { index: 0 });
      pane.items[2].getURI = null;
      pane.activateItemAtIndex(2);
      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.getActiveItem()).toEqual(newPane.itemAtIndex(1));
    });

    it('does not include items that cannot be deserialized', () => {
      spyOn(console, 'warn');
      const unserializable = {};
      pane.activateItem(unserializable);

      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.getActiveItem()).toEqual(pane.itemAtIndex(0));
      expect(newPane.getItems().length).toBe(pane.getItems().length - 1);
    });

    it("includes the pane's focus state in the serialized state", () => {
      pane.focus();
      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.focused).toBe(true);
    });

    it('can serialize and deserialize the order of the items in the itemStack', () => {
      const [item1, item2, item3] = pane.getItems();
      pane.itemStack = [item3, item1, item2];
      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.itemStack).toEqual(pane.itemStack);
      expect(newPane.itemStack[2]).toEqual(item2);
    });

    it('builds the itemStack if the itemStack is not serialized', () => {
      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.getItems()).toEqual(newPane.itemStack);
    });

    it('rebuilds the itemStack if items.length does not match itemStack.length', () => {
      const [, item2, item3] = pane.getItems();
      pane.itemStack = [item2, item3];
      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.getItems()).toEqual(newPane.itemStack);
    });

    it('does not serialize the reference to the items in the itemStack for pane items that will not be serialized', () => {
      const [item1, item2, item3] = pane.getItems();
      pane.itemStack = [item2, item1, item3];
      const unserializable = {};
      pane.activateItem(unserializable);

      const newPane = Pane.deserialize(pane.serialize(), atom);
      expect(newPane.itemStack).toEqual([item2, item1, item3]);
    });
  });
});
