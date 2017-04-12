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
    it('transfers focus back to the active center pane', () => {
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
      })
    })
  })
})
