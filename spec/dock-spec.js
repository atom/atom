/** @babel */

import etch from 'etch';

const Grim = require('grim');

const getNextUpdatePromise = () => etch.getScheduler().nextUpdatePromise;

describe('Dock', () => {
  describe('when a dock is activated', () => {
    it('opens the dock and activates its active pane', () => {
      jasmine.attachToDOM(atom.workspace.getElement());
      const dock = atom.workspace.getLeftDock();
      const didChangeVisibleSpy = jasmine.createSpy();
      dock.onDidChangeVisible(didChangeVisibleSpy);

      expect(dock.isVisible()).toBe(false);
      expect(document.activeElement).toBe(
        atom.workspace
          .getCenter()
          .getActivePane()
          .getElement()
      );
      dock.activate();
      expect(dock.isVisible()).toBe(true);
      expect(document.activeElement).toBe(dock.getActivePane().getElement());
      expect(didChangeVisibleSpy).toHaveBeenCalledWith(true);
    });
  });

  describe('when a dock is hidden', () => {
    it('transfers focus back to the active center pane if the dock had focus', () => {
      jasmine.attachToDOM(atom.workspace.getElement());
      const dock = atom.workspace.getLeftDock();
      const didChangeVisibleSpy = jasmine.createSpy();
      dock.onDidChangeVisible(didChangeVisibleSpy);

      dock.activate();
      expect(document.activeElement).toBe(dock.getActivePane().getElement());
      expect(didChangeVisibleSpy.mostRecentCall.args[0]).toBe(true);

      dock.hide();
      expect(document.activeElement).toBe(
        atom.workspace
          .getCenter()
          .getActivePane()
          .getElement()
      );
      expect(didChangeVisibleSpy.mostRecentCall.args[0]).toBe(false);

      dock.activate();
      expect(document.activeElement).toBe(dock.getActivePane().getElement());
      expect(didChangeVisibleSpy.mostRecentCall.args[0]).toBe(true);

      dock.toggle();
      expect(document.activeElement).toBe(
        atom.workspace
          .getCenter()
          .getActivePane()
          .getElement()
      );
      expect(didChangeVisibleSpy.mostRecentCall.args[0]).toBe(false);

      // Don't change focus if the dock was not focused in the first place
      const modalElement = document.createElement('div');
      modalElement.setAttribute('tabindex', -1);
      atom.workspace.addModalPanel({ item: modalElement });
      modalElement.focus();
      expect(document.activeElement).toBe(modalElement);

      dock.show();
      expect(document.activeElement).toBe(modalElement);
      expect(didChangeVisibleSpy.mostRecentCall.args[0]).toBe(true);

      dock.hide();
      expect(document.activeElement).toBe(modalElement);
      expect(didChangeVisibleSpy.mostRecentCall.args[0]).toBe(false);
    });
  });

  describe('when a pane in a dock is activated', () => {
    it('opens the dock', async () => {
      const item = {
        element: document.createElement('div'),
        getDefaultLocation() {
          return 'left';
        }
      };

      await atom.workspace.open(item, { activatePane: false });
      expect(atom.workspace.getLeftDock().isVisible()).toBe(false);

      atom.workspace
        .getLeftDock()
        .getPanes()[0]
        .activate();
      expect(atom.workspace.getLeftDock().isVisible()).toBe(true);
    });
  });

  describe('activating the next pane', () => {
    describe('when the dock has more than one pane', () => {
      it('activates the next pane', () => {
        const dock = atom.workspace.getLeftDock();
        const pane1 = dock.getPanes()[0];
        const pane2 = pane1.splitRight();
        const pane3 = pane2.splitRight();
        pane2.activate();
        expect(pane1.isActive()).toBe(false);
        expect(pane2.isActive()).toBe(true);
        expect(pane3.isActive()).toBe(false);

        dock.activateNextPane();
        expect(pane1.isActive()).toBe(false);
        expect(pane2.isActive()).toBe(false);
        expect(pane3.isActive()).toBe(true);
      });
    });

    describe('when the dock has only one pane', () => {
      it('leaves the current pane active', () => {
        const dock = atom.workspace.getLeftDock();

        expect(dock.getPanes().length).toBe(1);
        const pane = dock.getPanes()[0];
        expect(pane.isActive()).toBe(true);
        dock.activateNextPane();
        expect(pane.isActive()).toBe(true);
      });
    });
  });

  describe('activating the previous pane', () => {
    describe('when the dock has more than one pane', () => {
      it('activates the previous pane', () => {
        const dock = atom.workspace.getLeftDock();
        const pane1 = dock.getPanes()[0];
        const pane2 = pane1.splitRight();
        const pane3 = pane2.splitRight();
        pane2.activate();
        expect(pane1.isActive()).toBe(false);
        expect(pane2.isActive()).toBe(true);
        expect(pane3.isActive()).toBe(false);

        dock.activatePreviousPane();
        expect(pane1.isActive()).toBe(true);
        expect(pane2.isActive()).toBe(false);
        expect(pane3.isActive()).toBe(false);
      });
    });

    describe('when the dock has only one pane', () => {
      it('leaves the current pane active', () => {
        const dock = atom.workspace.getLeftDock();

        expect(dock.getPanes().length).toBe(1);
        const pane = dock.getPanes()[0];
        expect(pane.isActive()).toBe(true);
        dock.activatePreviousPane();
        expect(pane.isActive()).toBe(true);
      });
    });
  });

  describe('when the dock resize handle is double-clicked', () => {
    describe('when the dock is open', () => {
      it("resizes a vertically-oriented dock to the current item's preferred width", async () => {
        jasmine.attachToDOM(atom.workspace.getElement());

        const item = {
          element: document.createElement('div'),
          getDefaultLocation() {
            return 'left';
          },
          getPreferredWidth() {
            return 142;
          },
          getPreferredHeight() {
            return 122;
          }
        };

        await atom.workspace.open(item);
        const dock = atom.workspace.getLeftDock();
        const dockElement = dock.getElement();

        dock.setState({ size: 300 });
        await getNextUpdatePromise();
        expect(dockElement.offsetWidth).toBe(300);
        dockElement
          .querySelector('.atom-dock-resize-handle')
          .dispatchEvent(new MouseEvent('mousedown', { detail: 2 }));
        await getNextUpdatePromise();

        expect(dockElement.offsetWidth).toBe(item.getPreferredWidth());
      });

      it("resizes a horizontally-oriented dock to the current item's preferred width", async () => {
        jasmine.attachToDOM(atom.workspace.getElement());

        const item = {
          element: document.createElement('div'),
          getDefaultLocation() {
            return 'bottom';
          },
          getPreferredWidth() {
            return 122;
          },
          getPreferredHeight() {
            return 142;
          }
        };

        await atom.workspace.open(item);
        const dock = atom.workspace.getBottomDock();
        const dockElement = dock.getElement();

        dock.setState({ size: 300 });
        await getNextUpdatePromise();
        expect(dockElement.offsetHeight).toBe(300);
        dockElement
          .querySelector('.atom-dock-resize-handle')
          .dispatchEvent(new MouseEvent('mousedown', { detail: 2 }));
        await getNextUpdatePromise();

        expect(dockElement.offsetHeight).toBe(item.getPreferredHeight());
      });
    });

    describe('when the dock is closed', () => {
      it('does nothing', async () => {
        jasmine.attachToDOM(atom.workspace.getElement());

        const item = {
          element: document.createElement('div'),
          getDefaultLocation() {
            return 'bottom';
          },
          getPreferredWidth() {
            return 122;
          },
          getPreferredHeight() {
            return 142;
          }
        };

        await atom.workspace.open(item, { activatePane: false });

        const dockElement = atom.workspace.getBottomDock().getElement();
        dockElement
          .querySelector('.atom-dock-resize-handle')
          .dispatchEvent(new MouseEvent('mousedown', { detail: 2 }));
        expect(dockElement.offsetHeight).toBe(0);
        expect(dockElement.querySelector('.atom-dock-inner').offsetHeight).toBe(
          0
        );
        // The content should be masked away.
        expect(dockElement.querySelector('.atom-dock-mask').offsetHeight).toBe(
          0
        );
      });
    });
  });

  describe('when you add an item to an empty dock', () => {
    describe('when the item has a preferred size', () => {
      it('is takes the preferred size of the item', async () => {
        jasmine.attachToDOM(atom.workspace.getElement());

        const createItem = preferredWidth => ({
          element: document.createElement('div'),
          getDefaultLocation() {
            return 'left';
          },
          getPreferredWidth() {
            return preferredWidth;
          }
        });

        const dock = atom.workspace.getLeftDock();
        const dockElement = dock.getElement();
        expect(dock.getPaneItems()).toHaveLength(0);

        const item1 = createItem(111);
        await atom.workspace.open(item1);

        // It should update the width every time we go from 0 -> 1 items, not just the first.
        expect(dock.isVisible()).toBe(true);
        expect(dockElement.offsetWidth).toBe(111);
        dock.destroyActivePane();
        expect(dock.getPaneItems()).toHaveLength(0);
        expect(dock.isVisible()).toBe(false);
        const item2 = createItem(222);
        await atom.workspace.open(item2);
        expect(dock.isVisible()).toBe(true);
        expect(dockElement.offsetWidth).toBe(222);

        // Adding a second shouldn't change the size.
        const item3 = createItem(333);
        await atom.workspace.open(item3);
        expect(dockElement.offsetWidth).toBe(222);
      });
    });

    describe('when the item has no preferred size', () => {
      it('is still has an explicit size', async () => {
        jasmine.attachToDOM(atom.workspace.getElement());

        const item = {
          element: document.createElement('div'),
          getDefaultLocation() {
            return 'left';
          }
        };
        const dock = atom.workspace.getLeftDock();
        expect(dock.getPaneItems()).toHaveLength(0);

        expect(dock.state.size).toBe(null);
        await atom.workspace.open(item);
        expect(dock.state.size).not.toBe(null);
      });
    });
  });

  describe('a deserialized dock', () => {
    it('restores the serialized size', async () => {
      jasmine.attachToDOM(atom.workspace.getElement());

      const item = {
        element: document.createElement('div'),
        getDefaultLocation() {
          return 'left';
        },
        getPreferredWidth() {
          return 122;
        },
        serialize: () => ({ deserializer: 'DockTestItem' })
      };
      atom.deserializers.add({
        name: 'DockTestItem',
        deserialize: () => item
      });
      const dock = atom.workspace.getLeftDock();
      const dockElement = dock.getElement();

      await atom.workspace.open(item);
      dock.setState({ size: 150 });
      expect(dockElement.offsetWidth).toBe(150);
      const serialized = dock.serialize();
      dock.setState({ size: 122 });
      expect(dockElement.offsetWidth).toBe(122);
      dock.destroyActivePane();
      dock.deserialize(serialized, atom.deserializers);
      expect(dockElement.offsetWidth).toBe(150);
    });

    it("isn't visible if it has no items", async () => {
      jasmine.attachToDOM(atom.workspace.getElement());

      const item = {
        element: document.createElement('div'),
        getDefaultLocation() {
          return 'left';
        },
        getPreferredWidth() {
          return 122;
        }
      };
      const dock = atom.workspace.getLeftDock();

      await atom.workspace.open(item);
      expect(dock.isVisible()).toBe(true);
      const serialized = dock.serialize();
      dock.deserialize(serialized, atom.deserializers);
      expect(dock.getPaneItems()).toHaveLength(0);
      expect(dock.isVisible()).toBe(false);
    });
  });

  describe('drag handling', () => {
    it('expands docks to match the preferred size of the dragged item', async () => {
      jasmine.attachToDOM(atom.workspace.getElement());

      const element = document.createElement('div');
      element.setAttribute('is', 'tabs-tab');
      element.item = {
        element,
        getDefaultLocation() {
          return 'left';
        },
        getPreferredWidth() {
          return 144;
        }
      };

      const dragEvent = new DragEvent('dragstart');
      Object.defineProperty(dragEvent, 'target', { value: element });

      atom.workspace.getElement().handleDragStart(dragEvent);
      await getNextUpdatePromise();
      expect(atom.workspace.getLeftDock().refs.wrapperElement.offsetWidth).toBe(
        144
      );
    });

    it('does nothing when text nodes are dragged', () => {
      jasmine.attachToDOM(atom.workspace.getElement());

      const textNode = document.createTextNode('hello');

      const dragEvent = new DragEvent('dragstart');
      Object.defineProperty(dragEvent, 'target', { value: textNode });

      expect(() =>
        atom.workspace.getElement().handleDragStart(dragEvent)
      ).not.toThrow();
    });
  });

  describe('::getActiveTextEditor()', () => {
    it('is deprecated', () => {
      spyOn(Grim, 'deprecate');

      atom.workspace.getLeftDock().getActiveTextEditor();
      expect(Grim.deprecate.callCount).toBe(1);
    });
  });
});
