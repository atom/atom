const PaneContainer = require('../src/pane-container');

describe('PaneContainer', () => {
  let confirm, params;

  beforeEach(() => {
    confirm = spyOn(atom.applicationDelegate, 'confirm').andCallFake(
      (options, callback) => callback(0)
    );
    params = {
      location: 'center',
      config: atom.config,
      deserializerManager: atom.deserializers,
      applicationDelegate: atom.applicationDelegate,
      viewRegistry: atom.views
    };
  });

  describe('serialization', () => {
    let containerA, pane1A, pane2A, pane3A;

    beforeEach(() => {
      // This is a dummy item to prevent panes from being empty on deserialization
      class Item {
        static deserialize() {
          return new this();
        }
        serialize() {
          return { deserializer: 'Item' };
        }
      }
      atom.deserializers.add(Item);

      containerA = new PaneContainer(params);
      pane1A = containerA.getActivePane();
      pane1A.addItem(new Item());
      pane2A = pane1A.splitRight({ items: [new Item()] });
      pane3A = pane2A.splitDown({ items: [new Item()] });
      pane3A.focus();
    });

    it('preserves the focused pane across serialization', () => {
      expect(pane3A.focused).toBe(true);

      const containerB = new PaneContainer(params);
      containerB.deserialize(containerA.serialize(), atom.deserializers);
      const pane3B = containerB.getPanes()[2];
      expect(pane3B.focused).toBe(true);
    });

    it('preserves the active pane across serialization, independent of focus', () => {
      pane3A.activate();
      expect(containerA.getActivePane()).toBe(pane3A);

      const containerB = new PaneContainer(params);
      containerB.deserialize(containerA.serialize(), atom.deserializers);
      const pane3B = containerB.getPanes()[2];
      expect(containerB.getActivePane()).toBe(pane3B);
    });

    it('makes the first pane active if no pane exists for the activePaneId', () => {
      pane3A.activate();
      const state = containerA.serialize();
      state.activePaneId = -22;
      const containerB = new PaneContainer(params);
      containerB.deserialize(state, atom.deserializers);
      expect(containerB.getActivePane()).toBe(containerB.getPanes()[0]);
    });

    describe('if there are empty panes after deserialization', () => {
      beforeEach(() => {
        pane3A.getItems()[0].serialize = () => ({ deserializer: 'Bogus' });
      });

      describe("if the 'core.destroyEmptyPanes' config option is false (the default)", () =>
        it('leaves the empty panes intact', () => {
          const state = containerA.serialize();
          const containerB = new PaneContainer(params);
          containerB.deserialize(state, atom.deserializers);
          const [leftPane, column] = containerB.getRoot().getChildren();
          const [topPane, bottomPane] = column.getChildren();

          expect(leftPane.getItems().length).toBe(1);
          expect(topPane.getItems().length).toBe(1);
          expect(bottomPane.getItems().length).toBe(0);
        }));

      describe("if the 'core.destroyEmptyPanes' config option is true", () =>
        it('removes empty panes on deserialization', () => {
          atom.config.set('core.destroyEmptyPanes', true);

          const state = containerA.serialize();
          const containerB = new PaneContainer(params);
          containerB.deserialize(state, atom.deserializers);
          const [leftPane, rightPane] = containerB.getRoot().getChildren();

          expect(leftPane.getItems().length).toBe(1);
          expect(rightPane.getItems().length).toBe(1);
        }));
    });
  });

  it('does not allow the root pane to be destroyed', () => {
    const container = new PaneContainer(params);
    container.getRoot().destroy();
    expect(container.getRoot()).toBeDefined();
    expect(container.getRoot().isDestroyed()).toBe(false);
  });

  describe('::getActivePane()', () => {
    let container, pane1, pane2;

    beforeEach(() => {
      container = new PaneContainer(params);
      pane1 = container.getRoot();
    });

    it('returns the first pane if no pane has been made active', () => {
      expect(container.getActivePane()).toBe(pane1);
      expect(pane1.isActive()).toBe(true);
    });

    it('returns the most pane on which ::activate() was most recently called', () => {
      pane2 = pane1.splitRight();
      pane2.activate();
      expect(container.getActivePane()).toBe(pane2);
      expect(pane1.isActive()).toBe(false);
      expect(pane2.isActive()).toBe(true);
      pane1.activate();
      expect(container.getActivePane()).toBe(pane1);
      expect(pane1.isActive()).toBe(true);
      expect(pane2.isActive()).toBe(false);
    });

    it('returns the next pane if the current active pane is destroyed', () => {
      pane2 = pane1.splitRight();
      pane2.activate();
      pane2.destroy();
      expect(container.getActivePane()).toBe(pane1);
      expect(pane1.isActive()).toBe(true);
    });
  });

  describe('::onDidChangeActivePane()', () => {
    let container, pane1, pane2, observed;

    beforeEach(() => {
      container = new PaneContainer(params);
      container.getRoot().addItems([{}, {}]);
      container.getRoot().splitRight({ items: [{}, {}] });
      [pane1, pane2] = container.getPanes();

      observed = [];
      container.onDidChangeActivePane(pane => observed.push(pane));
    });

    it('invokes observers when the active pane changes', () => {
      pane1.activate();
      pane2.activate();
      expect(observed).toEqual([pane1, pane2]);
    });
  });

  describe('::onDidChangeActivePaneItem()', () => {
    let container, pane1, pane2, observed;

    beforeEach(() => {
      container = new PaneContainer(params);
      container.getRoot().addItems([{}, {}]);
      container.getRoot().splitRight({ items: [{}, {}] });
      [pane1, pane2] = container.getPanes();

      observed = [];
      container.onDidChangeActivePaneItem(item => observed.push(item));
    });

    it('invokes observers when the active item of the active pane changes', () => {
      pane2.activateNextItem();
      pane2.activateNextItem();
      expect(observed).toEqual([pane2.itemAtIndex(1), pane2.itemAtIndex(0)]);
    });

    it('invokes observers when the active pane changes', () => {
      pane1.activate();
      pane2.activate();
      expect(observed).toEqual([pane1.itemAtIndex(0), pane2.itemAtIndex(0)]);
    });
  });

  describe('::onDidStopChangingActivePaneItem()', () => {
    let container, pane1, pane2, observed;

    beforeEach(() => {
      container = new PaneContainer(params);
      container.getRoot().addItems([{}, {}]);
      container.getRoot().splitRight({ items: [{}, {}] });
      [pane1, pane2] = container.getPanes();

      observed = [];
      container.onDidStopChangingActivePaneItem(item => observed.push(item));
    });

    it('invokes observers once when the active item of the active pane changes', () => {
      pane2.activateNextItem();
      pane2.activateNextItem();
      expect(observed).toEqual([]);
      advanceClock(100);
      expect(observed).toEqual([pane2.itemAtIndex(0)]);
    });

    it('invokes observers once when the active pane changes', () => {
      pane1.activate();
      pane2.activate();
      expect(observed).toEqual([]);
      advanceClock(100);
      expect(observed).toEqual([pane2.itemAtIndex(0)]);
    });
  });

  describe('::onDidActivatePane', () => {
    it('invokes observers when a pane is activated (even if it was already active)', () => {
      const container = new PaneContainer(params);
      container.getRoot().splitRight();
      const [pane1, pane2] = container.getPanes();

      const activatedPanes = [];
      container.onDidActivatePane(pane => activatedPanes.push(pane));

      pane1.activate();
      pane1.activate();
      pane2.activate();
      pane2.activate();
      expect(activatedPanes).toEqual([pane1, pane1, pane2, pane2]);
    });
  });

  describe('::observePanes()', () => {
    it('invokes observers with all current and future panes', () => {
      const container = new PaneContainer(params);
      container.getRoot().splitRight();
      const [pane1, pane2] = container.getPanes();

      const observed = [];
      container.observePanes(pane => observed.push(pane));

      const pane3 = pane2.splitDown();
      const pane4 = pane2.splitRight();

      expect(observed).toEqual([pane1, pane2, pane3, pane4]);
    });
  });

  describe('::observePaneItems()', () =>
    it('invokes observers with all current and future pane items', () => {
      const container = new PaneContainer(params);
      container.getRoot().addItems([{}, {}]);
      container.getRoot().splitRight({ items: [{}] });
      const pane2 = container.getPanes()[1];
      const observed = [];
      container.observePaneItems(pane => observed.push(pane));

      const pane3 = pane2.splitDown({ items: [{}] });
      pane3.addItems([{}, {}]);

      expect(observed).toEqual(container.getPaneItems());
    }));

  describe('::confirmClose()', () => {
    let container, pane1, pane2;

    beforeEach(() => {
      class TestItem {
        shouldPromptToSave() {
          return true;
        }
        getURI() {
          return 'test';
        }
      }

      container = new PaneContainer(params);
      container.getRoot().splitRight();
      [pane1, pane2] = container.getPanes();
      pane1.addItem(new TestItem());
      pane2.addItem(new TestItem());
    });

    it('returns true if the user saves all modified files when prompted', async () => {
      confirm.andCallFake((options, callback) => callback(0));
      const saved = await container.confirmClose();
      expect(confirm).toHaveBeenCalled();
      expect(saved).toBeTruthy();
    });

    it('returns false if the user cancels saving any modified file', async () => {
      confirm.andCallFake((options, callback) => callback(1));
      const saved = await container.confirmClose();
      expect(confirm).toHaveBeenCalled();
      expect(saved).toBeFalsy();
    });
  });

  describe('::onDidAddPane(callback)', () => {
    it('invokes the given callback when panes are added', () => {
      const container = new PaneContainer(params);
      const events = [];
      container.onDidAddPane(event => {
        expect(container.getPanes().includes(event.pane)).toBe(true);
        events.push(event);
      });

      const pane1 = container.getActivePane();
      const pane2 = pane1.splitRight();
      const pane3 = pane2.splitDown();

      expect(events).toEqual([{ pane: pane2 }, { pane: pane3 }]);
    });
  });

  describe('::onWillDestroyPane(callback)', () => {
    it('invokes the given callback before panes or their items are destroyed', () => {
      class TestItem {
        constructor() {
          this._isDestroyed = false;
        }
        destroy() {
          this._isDestroyed = true;
        }
        isDestroyed() {
          return this._isDestroyed;
        }
      }

      const container = new PaneContainer(params);
      const events = [];
      container.onWillDestroyPane(event => {
        const itemsDestroyed = event.pane
          .getItems()
          .map(item => item.isDestroyed());
        events.push([event, { itemsDestroyed }]);
      });

      const pane1 = container.getActivePane();
      const pane2 = pane1.splitRight();
      pane2.addItem(new TestItem());

      pane2.destroy();

      expect(events).toEqual([[{ pane: pane2 }, { itemsDestroyed: [false] }]]);
    });
  });

  describe('::onDidDestroyPane(callback)', () => {
    it('invokes the given callback when panes are destroyed', () => {
      const container = new PaneContainer(params);
      const events = [];
      container.onDidDestroyPane(event => {
        expect(container.getPanes().includes(event.pane)).toBe(false);
        events.push(event);
      });

      const pane1 = container.getActivePane();
      const pane2 = pane1.splitRight();
      const pane3 = pane2.splitDown();

      pane2.destroy();
      pane3.destroy();

      expect(events).toEqual([{ pane: pane2 }, { pane: pane3 }]);
    });

    it('invokes the given callback when the container is destroyed', () => {
      const container = new PaneContainer(params);
      const events = [];
      container.onDidDestroyPane(event => {
        expect(container.getPanes().includes(event.pane)).toBe(false);
        events.push(event);
      });

      const pane1 = container.getActivePane();
      const pane2 = pane1.splitRight();
      const pane3 = pane2.splitDown();

      container.destroy();

      expect(events).toEqual([
        { pane: pane1 },
        { pane: pane2 },
        { pane: pane3 }
      ]);
    });
  });

  describe('::onWillDestroyPaneItem() and ::onDidDestroyPaneItem()', () => {
    it('invokes the given callbacks when an item will be destroyed on any pane', async () => {
      const container = new PaneContainer(params);
      const pane1 = container.getRoot();
      const item1 = {};
      const item2 = {};
      const item3 = {};

      pane1.addItem(item1);
      const events = [];
      container.onWillDestroyPaneItem(event => events.push(['will', event]));
      container.onDidDestroyPaneItem(event => events.push(['did', event]));
      const pane2 = pane1.splitRight({ items: [item2, item3] });

      await pane1.destroyItem(item1);
      await pane2.destroyItem(item3);
      await pane2.destroyItem(item2);

      expect(events.length).toBe(6);
      expect(events[1]).toEqual([
        'did',
        { item: item1, pane: pane1, index: 0 }
      ]);
      expect(events[3]).toEqual([
        'did',
        { item: item3, pane: pane2, index: 1 }
      ]);
      expect(events[5]).toEqual([
        'did',
        { item: item2, pane: pane2, index: 0 }
      ]);

      expect(events[0][0]).toEqual('will');
      expect(events[0][1].item).toEqual(item1);
      expect(events[0][1].pane).toEqual(pane1);
      expect(events[0][1].index).toEqual(0);
      expect(typeof events[0][1].prevent).toEqual('function');

      expect(events[2][0]).toEqual('will');
      expect(events[2][1].item).toEqual(item3);
      expect(events[2][1].pane).toEqual(pane2);
      expect(events[2][1].index).toEqual(1);
      expect(typeof events[2][1].prevent).toEqual('function');

      expect(events[4][0]).toEqual('will');
      expect(events[4][1].item).toEqual(item2);
      expect(events[4][1].pane).toEqual(pane2);
      expect(events[4][1].index).toEqual(0);
      expect(typeof events[4][1].prevent).toEqual('function');
    });
  });

  describe('::saveAll()', () =>
    it('saves all modified pane items', async () => {
      const container = new PaneContainer(params);
      const pane1 = container.getRoot();
      pane1.splitRight();

      const item1 = {
        saved: false,
        getURI() {
          return '';
        },
        isModified() {
          return true;
        },
        save() {
          this.saved = true;
        }
      };
      const item2 = {
        saved: false,
        getURI() {
          return '';
        },
        isModified() {
          return false;
        },
        save() {
          this.saved = true;
        }
      };
      const item3 = {
        saved: false,
        getURI() {
          return '';
        },
        isModified() {
          return true;
        },
        save() {
          this.saved = true;
        }
      };

      pane1.addItem(item1);
      pane1.addItem(item2);
      pane1.addItem(item3);

      container.saveAll();

      expect(item1.saved).toBe(true);
      expect(item2.saved).toBe(false);
      expect(item3.saved).toBe(true);
    }));

  describe('::moveActiveItemToPane(destPane) and ::copyActiveItemToPane(destPane)', () => {
    let container, pane1, pane2, item1;

    beforeEach(() => {
      class TestItem {
        constructor(id) {
          this.id = id;
        }
        copy() {
          return new TestItem(this.id);
        }
      }

      container = new PaneContainer(params);
      pane1 = container.getRoot();
      item1 = new TestItem('1');
      pane2 = pane1.splitRight({ items: [item1] });
    });

    describe('::::moveActiveItemToPane(destPane)', () =>
      it('moves active item to given pane and focuses it', () => {
        container.moveActiveItemToPane(pane1);
        expect(pane1.getActiveItem()).toBe(item1);
      }));

    describe('::::copyActiveItemToPane(destPane)', () =>
      it('copies active item to given pane and focuses it', () => {
        container.copyActiveItemToPane(pane1);
        expect(container.paneForItem(item1)).toBe(pane2);
        expect(pane1.getActiveItem().id).toBe(item1.id);
      }));
  });
});
