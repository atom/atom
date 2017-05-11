/** @babel */

import {it, fit, ffit, fffit, beforeEach, afterEach} from './async-spec-helpers'

describe('Dock', () => {
  describe('when a dock is activated', () => {
    it('opens the dock and activates its active pane', () => {
      jasmine.attachToDOM(atom.workspace.getElement())
      const dock = atom.workspace.getLeftDock()

      expect(dock.isVisible()).toBe(false)
      expect(document.activeElement).toBe(atom.workspace.getCenter().getActivePane().getElement())
      dock.activate()
      expect(dock.isVisible()).toBe(true)
      expect(document.activeElement).toBe(dock.getActivePane().getElement())
    })
  })

  describe('when a dock is hidden', () => {
    it('transfers focus back to the active center pane if the dock had focus', () => {
      jasmine.attachToDOM(atom.workspace.getElement())
      const dock = atom.workspace.getLeftDock()
      dock.activate()
      expect(document.activeElement).toBe(dock.getActivePane().getElement())

      dock.hide()
      expect(document.activeElement).toBe(atom.workspace.getCenter().getActivePane().getElement())

      dock.activate()
      expect(document.activeElement).toBe(dock.getActivePane().getElement())

      dock.toggle()
      expect(document.activeElement).toBe(atom.workspace.getCenter().getActivePane().getElement())

      // Don't change focus if the dock was not focused in the first place
      const modalElement = document.createElement('div')
      modalElement.setAttribute('tabindex', -1)
      atom.workspace.addModalPanel({item: modalElement})
      modalElement.focus()
      expect(document.activeElement).toBe(modalElement)

      dock.show()
      expect(document.activeElement).toBe(modalElement)

      dock.hide()
      expect(document.activeElement).toBe(modalElement)
    })
  })

  describe('when a pane in a dock is activated', () => {
    it('opens the dock', async () => {
      const item = {
        element: document.createElement('div'),
        getDefaultLocation() { return 'left' }
      }

      await atom.workspace.open(item, {activatePane: false})
      expect(atom.workspace.getLeftDock().isVisible()).toBe(false)

      atom.workspace.getLeftDock().getPanes()[0].activate()
      expect(atom.workspace.getLeftDock().isVisible()).toBe(true)
    })
  })

  describe('when the dock resize handle is double-clicked', () => {
    describe('when the dock is open', () => {
      it('resizes a vertically-oriented dock to the current item\'s preferred width', async () => {
        jasmine.attachToDOM(atom.workspace.getElement())

        const item = {
          element: document.createElement('div'),
          getDefaultLocation() { return 'left' },
          getPreferredWidth() { return 142 },
          getPreferredHeight() { return 122 }
        }

        await atom.workspace.open(item)
        const dock = atom.workspace.getLeftDock()
        const dockElement = dock.getElement()

        dock.setState({size: 300})
        expect(dockElement.offsetWidth).toBe(300)
        dockElement.querySelector('.atom-dock-resize-handle').dispatchEvent(new MouseEvent('mousedown', {detail: 2}))

        expect(dockElement.offsetWidth).toBe(item.getPreferredWidth())
      })

      it('resizes a horizontally-oriented dock to the current item\'s preferred width', async () => {
        jasmine.attachToDOM(atom.workspace.getElement())

        const item = {
          element: document.createElement('div'),
          getDefaultLocation() { return 'bottom' },
          getPreferredWidth() { return 122 },
          getPreferredHeight() { return 142 }
        }

        await atom.workspace.open(item)
        const dock = atom.workspace.getBottomDock()
        const dockElement = dock.getElement()

        dock.setState({size: 300})
        expect(dockElement.offsetHeight).toBe(300)
        dockElement.querySelector('.atom-dock-resize-handle').dispatchEvent(new MouseEvent('mousedown', {detail: 2}))

        expect(dockElement.offsetHeight).toBe(item.getPreferredHeight())
      })
    })

    describe('when the dock is closed', () => {
      it('does nothing', async () => {
        jasmine.attachToDOM(atom.workspace.getElement())

        const item = {
          element: document.createElement('div'),
          getDefaultLocation() { return 'bottom' },
          getPreferredWidth() { return 122 },
          getPreferredHeight() { return 142 }
        }

        await atom.workspace.open(item, {activatePane: false})

        const dockElement = atom.workspace.getBottomDock().getElement()
        dockElement.querySelector('.atom-dock-resize-handle').dispatchEvent(new MouseEvent('mousedown', {detail: 2}))
        expect(dockElement.offsetHeight).toBe(0)

        // There should still be a hoverable, absolutely-positioned element so users can reveal the
        // toggle affordance even when fullscreened.
        expect(dockElement.querySelector('.atom-dock-inner').offsetHeight).toBe(1)

        // The content should be masked away.
        expect(dockElement.querySelector('.atom-dock-mask').offsetHeight).toBe(0)
      })
    })
  })

  describe('when you add an item to an empty dock', () => {
    describe('when the item has a preferred size', () => {
      it('is takes the preferred size of the item', async () => {
        jasmine.attachToDOM(atom.workspace.getElement())

        const createItem = preferredWidth => ({
          element: document.createElement('div'),
          getDefaultLocation() { return 'left' },
          getPreferredWidth() { return preferredWidth }
        })

        const dock = atom.workspace.getLeftDock()
        const dockElement = dock.getElement()
        expect(dock.getPaneItems()).toHaveLength(0)

        const item1 = createItem(111)
        await atom.workspace.open(item1)

        // It should update the width every time we go from 0 -> 1 items, not just the first.
        expect(dock.isVisible()).toBe(true)
        expect(dockElement.offsetWidth).toBe(111)
        dock.destroyActivePane()
        expect(dock.getPaneItems()).toHaveLength(0)
        expect(dock.isVisible()).toBe(false)
        const item2 = createItem(222)
        await atom.workspace.open(item2)
        expect(dock.isVisible()).toBe(true)
        expect(dockElement.offsetWidth).toBe(222)

        // Adding a second shouldn't change the size.
        const item3 = createItem(333)
        await atom.workspace.open(item3)
        expect(dockElement.offsetWidth).toBe(222)
      })
    })

    describe('when the item has no preferred size', () => {
      it('is still has an explicit size', async () => {
        jasmine.attachToDOM(atom.workspace.getElement())

        const item = {
          element: document.createElement('div'),
          getDefaultLocation() { return 'left' }
        }
        const dock = atom.workspace.getLeftDock()
        expect(dock.getPaneItems()).toHaveLength(0)

        expect(dock.state.size).toBe(null)
        await atom.workspace.open(item)
        expect(dock.state.size).not.toBe(null)
      })
    })
  })

  describe('a deserialized dock', () => {
    it('restores the serialized size', async () => {
      jasmine.attachToDOM(atom.workspace.getElement())

      const item = {
        element: document.createElement('div'),
        getDefaultLocation() { return 'left' },
        getPreferredWidth() { return 122 },
        serialize: () => ({deserializer: 'DockTestItem'})
      }
      const itemDeserializer = atom.deserializers.add({
        name: 'DockTestItem',
        deserialize: () => item
      })
      const dock = atom.workspace.getLeftDock()
      const dockElement = dock.getElement()

      await atom.workspace.open(item)
      dock.setState({size: 150})
      expect(dockElement.offsetWidth).toBe(150)
      const serialized = dock.serialize()
      dock.setState({size: 122})
      expect(dockElement.offsetWidth).toBe(122)
      dock.destroyActivePane()
      dock.deserialize(serialized, atom.deserializers)
      expect(dockElement.offsetWidth).toBe(150)
    })

    it("isn't visible if it has no items", async () => {
      jasmine.attachToDOM(atom.workspace.getElement())

      const item = {
        element: document.createElement('div'),
        getDefaultLocation() { return 'left' },
        getPreferredWidth() { return 122 }
      }
      const dock = atom.workspace.getLeftDock()

      await atom.workspace.open(item)
      expect(dock.isVisible()).toBe(true)
      const serialized = dock.serialize()
      dock.deserialize(serialized, atom.deserializers)
      expect(dock.getPaneItems()).toHaveLength(0)
      expect(dock.isVisible()).toBe(false)
    })
  })

  describe('when dragging an item over an empty dock', () => {
    it('has the preferred size of the item', () => {
      jasmine.attachToDOM(atom.workspace.getElement())

      const item = {
        element: document.createElement('div'),
        getDefaultLocation() { return 'left' },
        getPreferredWidth() { return 144 },
        serialize: () => ({deserializer: 'DockTestItem'})
      }
      const dock = atom.workspace.getLeftDock()
      const dockElement = dock.getElement()

      dock.setDraggingItem(item)
      expect(dock.wrapperElement.offsetWidth).toBe(144)
    })
  })
})
