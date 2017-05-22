/** @babel */

/* global getComputedStyle, WheelEvent */

const {ipcRenderer} = require('electron')
const path = require('path')
const temp = require('temp').track()
const PaneContainer = require('../src/pane-container')
const {Disposable} = require('event-kit')
const {it, fit, ffit, fffit, beforeEach, afterEach} = require('./async-spec-helpers')

describe('WorkspaceElement', () => {
  afterEach(() => { temp.cleanupSync() })

  describe('when the workspace element is focused', () => {
    it('transfers focus to the active pane', () => {
      const workspaceElement = atom.workspace.getElement()
      jasmine.attachToDOM(workspaceElement)
      const activePaneElement = atom.workspace.getActivePane().getElement()
      document.body.focus()
      expect(document.activeElement).not.toBe(activePaneElement)
      workspaceElement.focus()
      expect(document.activeElement).toBe(activePaneElement)
    })
  })

  describe('when the active pane of an inactive pane container is focused', () => {
    it('changes the active pane container', () => {
      const dock = atom.workspace.getLeftDock()
      dock.show()
      jasmine.attachToDOM(atom.workspace.getElement())
      expect(atom.workspace.getActivePaneContainer()).toBe(atom.workspace.getCenter())
      dock.getActivePane().getElement().focus()
      expect(atom.workspace.getActivePaneContainer()).toBe(dock)
    })
  })

  describe('changing focus, copying, and moving items directionally between panes', function () {
    let pane1, pane2, pane3, pane4, pane5, pane6, pane7, pane8, pane9,
      workspace, containerElement

    beforeEach(function () {
      atom.config.set('core.destroyEmptyPanes', false)
      expect(document.hasFocus()).toBe(true, 'Document needs to be focused to run this test')

      workspace = atom.workspace

      // Set up a grid of 9 panes, in the following arrangement, where the
      // numbers correspond to the variable names below.
      //
      // -------
      // |1|2|3|
      // -------
      // |4|5|6|
      // -------
      // |7|8|9|
      // -------

      const container = workspace.getActivePaneContainer()
      expect(container.getLocation()).toEqual('center')
      expect(container.getPanes().length).toEqual(1)

      pane1 = container.getActivePane()
      pane4 = pane1.splitDown()
      pane7 = pane4.splitDown()

      pane2 = pane1.splitRight()
      pane3 = pane2.splitRight()

      pane5 = pane4.splitRight()
      pane6 = pane5.splitRight()

      pane8 = pane7.splitRight()
      pane9 = pane8.splitRight()

      containerElement = container.paneContainer.getElement()
      containerElement.style.height = '400px'
      containerElement.style.width = '400px'
      jasmine.attachToDOM(containerElement)
    })

    describe('::focusPaneViewAbove()', function () {
      describe('when there are multiple rows above the focused pane', () =>
        it('focuses up to the adjacent row', function () {
          pane8.activate()
          containerElement.focusPaneViewAbove()
          expect(document.activeElement).toBe(pane5.getElement())
        })
      )

      describe('when there are no rows above the focused pane', () =>
        it('keeps the current pane focused', function () {
          pane2.activate()
          containerElement.focusPaneViewAbove()
          expect(document.activeElement).toBe(pane2.getElement())
        })
      )
    })

    describe('::focusPaneViewBelow()', function () {
      describe('when there are multiple rows below the focused pane', () =>
        it('focuses down to the adjacent row', function () {
          pane2.activate()
          containerElement.focusPaneViewBelow()
          expect(document.activeElement).toBe(pane5.getElement())
        })
      )

      describe('when there are no rows below the focused pane', () =>
        it('keeps the current pane focused', function () {
          pane8.activate()
          containerElement.focusPaneViewBelow()
          expect(document.activeElement).toBe(pane8.getElement())
        })
      )
    })

    describe('::focusPaneViewOnLeft()', function () {
      describe('when there are multiple columns to the left of the focused pane', () =>
        it('focuses left to the adjacent column', function () {
          pane6.activate()
          containerElement.focusPaneViewOnLeft()
          expect(document.activeElement).toBe(pane5.getElement())
        })
      )

      describe('when there are no columns to the left of the focused pane', () =>
        it('keeps the current pane focused', function () {
          pane4.activate()
          containerElement.focusPaneViewOnLeft()
          expect(document.activeElement).toBe(pane4.getElement())
        })
      )
    })

    describe('::focusPaneViewOnRight()', function () {
      describe('when there are multiple columns to the right of the focused pane', () =>
        it('focuses right to the adjacent column', function () {
          pane4.activate()
          containerElement.focusPaneViewOnRight()
          expect(document.activeElement).toBe(pane5.getElement())
        })
      )

      describe('when there are no columns to the right of the focused pane', () =>
        it('keeps the current pane focused', function () {
          pane6.activate()
          containerElement.focusPaneViewOnRight()
          expect(document.activeElement).toBe(pane6.getElement())
        })
      )
    })

    describe('::moveActiveItemToPaneAbove(keepOriginal)', function () {
      describe('when there are multiple rows above the focused pane', () =>
        it('moves the active item up to the adjacent row', function () {
          const item = document.createElement('div')
          pane8.activate()
          pane8.activateItem(item)
          containerElement.moveActiveItemToPaneAbove()
          expect(workspace.paneForItem(item)).toBe(pane5)
          expect(pane5.getActiveItem()).toBe(item)
        })
      )

      describe('when there are no rows above the focused pane', () =>
        it('keeps the active pane focused', function () {
          const item = document.createElement('div')
          pane2.activate()
          pane2.activateItem(item)
          containerElement.moveActiveItemToPaneAbove()
          expect(workspace.paneForItem(item)).toBe(pane2)
        })
      )

      describe('when `keepOriginal: true` is passed in the params', () =>
        it('keeps the item and adds a copy of it to the adjacent pane', function () {
          const itemA = document.createElement('div')
          const itemB = document.createElement('div')
          itemA.copy = () => itemB
          pane8.activate()
          pane8.activateItem(itemA)
          containerElement.moveActiveItemToPaneAbove({keepOriginal: true})
          expect(workspace.paneForItem(itemA)).toBe(pane8)
          expect(pane5.getActiveItem()).toBe(itemB)
        })
      )
    })

    describe('::moveActiveItemToPaneBelow(keepOriginal)', function () {
      describe('when there are multiple rows below the focused pane', () =>
        it('moves the active item down to the adjacent row', function () {
          const item = document.createElement('div')
          pane2.activate()
          pane2.activateItem(item)
          containerElement.moveActiveItemToPaneBelow()
          expect(workspace.paneForItem(item)).toBe(pane5)
          expect(pane5.getActiveItem()).toBe(item)
        })
      )

      describe('when there are no rows below the focused pane', () =>
        it('keeps the active item in the focused pane', function () {
          const item = document.createElement('div')
          pane8.activate()
          pane8.activateItem(item)
          containerElement.moveActiveItemToPaneBelow()
          expect(workspace.paneForItem(item)).toBe(pane8)
        })
      )

      describe('when `keepOriginal: true` is passed in the params', () =>
        it('keeps the item and adds a copy of it to the adjacent pane', function () {
          const itemA = document.createElement('div')
          const itemB = document.createElement('div')
          itemA.copy = () => itemB
          pane2.activate()
          pane2.activateItem(itemA)
          containerElement.moveActiveItemToPaneBelow({keepOriginal: true})
          expect(workspace.paneForItem(itemA)).toBe(pane2)
          expect(pane5.getActiveItem()).toBe(itemB)
        })
      )
    })

    describe('::moveActiveItemToPaneOnLeft(keepOriginal)', function () {
      describe('when there are multiple columns to the left of the focused pane', () =>
        it('moves the active item left to the adjacent column', function () {
          const item = document.createElement('div')
          pane6.activate()
          pane6.activateItem(item)
          containerElement.moveActiveItemToPaneOnLeft()
          expect(workspace.paneForItem(item)).toBe(pane5)
          expect(pane5.getActiveItem()).toBe(item)
        })
      )

      describe('when there are no columns to the left of the focused pane', () =>
        it('keeps the active item in the focused pane', function () {
          const item = document.createElement('div')
          pane4.activate()
          pane4.activateItem(item)
          containerElement.moveActiveItemToPaneOnLeft()
          expect(workspace.paneForItem(item)).toBe(pane4)
        })
      )

      describe('when `keepOriginal: true` is passed in the params', () =>
        it('keeps the item and adds a copy of it to the adjacent pane', function () {
          const itemA = document.createElement('div')
          const itemB = document.createElement('div')
          itemA.copy = () => itemB
          pane6.activate()
          pane6.activateItem(itemA)
          containerElement.moveActiveItemToPaneOnLeft({keepOriginal: true})
          expect(workspace.paneForItem(itemA)).toBe(pane6)
          expect(pane5.getActiveItem()).toBe(itemB)
        })
      )
    })

    describe('::moveActiveItemToPaneOnRight(keepOriginal)', function () {
      describe('when there are multiple columns to the right of the focused pane', () =>
        it('moves the active item right to the adjacent column', function () {
          const item = document.createElement('div')
          pane4.activate()
          pane4.activateItem(item)
          containerElement.moveActiveItemToPaneOnRight()
          expect(workspace.paneForItem(item)).toBe(pane5)
          expect(pane5.getActiveItem()).toBe(item)
        })
      )

      describe('when there are no columns to the right of the focused pane', () =>
        it('keeps the active item in the focused pane', function () {
          const item = document.createElement('div')
          pane6.activate()
          pane6.activateItem(item)
          containerElement.moveActiveItemToPaneOnRight()
          expect(workspace.paneForItem(item)).toBe(pane6)
        })
      )

      describe('when `keepOriginal: true` is passed in the params', () =>
        it('keeps the item and adds a copy of it to the adjacent pane', function () {
          const itemA = document.createElement('div')
          const itemB = document.createElement('div')
          itemA.copy = () => itemB
          pane4.activate()
          pane4.activateItem(itemA)
          containerElement.moveActiveItemToPaneOnRight({keepOriginal: true})
          expect(workspace.paneForItem(itemA)).toBe(pane4)
          expect(pane5.getActiveItem()).toBe(itemB)
        })
      )
    })
  })

  describe('mousing over docks', () => {
    let workspaceElement

    beforeEach(() => {
      workspaceElement = atom.workspace.getElement()
      workspaceElement.style.width = '600px'
      workspaceElement.style.height = '300px'
      jasmine.attachToDOM(workspaceElement)
    })

    it('shows the toggle button when the dock is open', async () => {
      await Promise.all([
        atom.workspace.open({
          element: document.createElement('div'),
          getDefaultLocation() { return 'left' },
          getPreferredWidth() { return 150 }
        }),
        atom.workspace.open({
          element: document.createElement('div'),
          getDefaultLocation() { return 'right' },
          getPreferredWidth() { return 150 }
        }),
        atom.workspace.open({
          element: document.createElement('div'),
          getDefaultLocation() { return 'bottom' },
          getPreferredHeight() { return 100 }
        })
      ])

      const leftDock = atom.workspace.getLeftDock()
      const rightDock = atom.workspace.getRightDock()
      const bottomDock = atom.workspace.getBottomDock()

      expect(leftDock.isVisible()).toBe(true)
      expect(rightDock.isVisible()).toBe(true)
      expect(bottomDock.isVisible()).toBe(true)
      expectToggleButtonHidden(leftDock)
      expectToggleButtonHidden(rightDock)
      expectToggleButtonHidden(bottomDock)

      workspaceElement.paneContainer.dispatchEvent(new MouseEvent('mouseleave'))

      // --- Right Dock ---

      // Mouse over where the toggle button would be if the dock were hovered
      moveMouse({clientX: 440, clientY: 150})
      expectToggleButtonHidden(leftDock)
      expectToggleButtonHidden(rightDock)
      expectToggleButtonHidden(bottomDock)

      // Mouse over the dock
      moveMouse({clientX: 460, clientY: 150})
      expectToggleButtonHidden(leftDock)
      expectToggleButtonVisible(rightDock, 'icon-chevron-right')
      expectToggleButtonHidden(bottomDock)

      // Mouse over the toggle button
      moveMouse({clientX: 440, clientY: 150})
      expectToggleButtonHidden(leftDock)
      expectToggleButtonVisible(rightDock, 'icon-chevron-right')
      expectToggleButtonHidden(bottomDock)

      // Click the toggle button
      rightDock.toggleButton.innerElement.click()
      expect(rightDock.isVisible()).toBe(false)
      expectToggleButtonHidden(rightDock)

      // Mouse to edge of the window
      moveMouse({clientX: 575, clientY: 150})
      expectToggleButtonHidden(rightDock)
      moveMouse({clientX: 600, clientY: 150})
      expectToggleButtonVisible(rightDock, 'icon-chevron-left')

      // Click the toggle button again
      rightDock.toggleButton.innerElement.click()
      expect(rightDock.isVisible()).toBe(true)
      expectToggleButtonVisible(rightDock, 'icon-chevron-right')

      // --- Left Dock ---

      // Mouse over where the toggle button would be if the dock were hovered
      moveMouse({clientX: 160, clientY: 150})
      expectToggleButtonHidden(leftDock)
      expectToggleButtonHidden(rightDock)
      expectToggleButtonHidden(bottomDock)

      // Mouse over the dock
      moveMouse({clientX: 140, clientY: 150})
      expectToggleButtonVisible(leftDock, 'icon-chevron-left')
      expectToggleButtonHidden(rightDock)
      expectToggleButtonHidden(bottomDock)

      // Mouse over the toggle button
      moveMouse({clientX: 160, clientY: 150})
      expectToggleButtonVisible(leftDock, 'icon-chevron-left')
      expectToggleButtonHidden(rightDock)
      expectToggleButtonHidden(bottomDock)

      // Click the toggle button
      leftDock.toggleButton.innerElement.click()
      expect(leftDock.isVisible()).toBe(false)
      expectToggleButtonHidden(leftDock)

      // Mouse to edge of the window
      moveMouse({clientX: 25, clientY: 150})
      expectToggleButtonHidden(leftDock)
      moveMouse({clientX: 0, clientY: 150})
      expectToggleButtonVisible(leftDock, 'icon-chevron-right')

      // Click the toggle button again
      leftDock.toggleButton.innerElement.click()
      expect(leftDock.isVisible()).toBe(true)
      expectToggleButtonVisible(leftDock, 'icon-chevron-left')

      // --- Bottom Dock ---

      // Mouse over where the toggle button would be if the dock were hovered
      moveMouse({clientX: 300, clientY: 190})
      expectToggleButtonHidden(leftDock)
      expectToggleButtonHidden(rightDock)
      expectToggleButtonHidden(bottomDock)

      // Mouse over the dock
      moveMouse({clientX: 300, clientY: 210})
      expectToggleButtonHidden(leftDock)
      expectToggleButtonHidden(rightDock)
      expectToggleButtonVisible(bottomDock, 'icon-chevron-down')

      // Mouse over the toggle button
      moveMouse({clientX: 300, clientY: 195})
      expectToggleButtonHidden(leftDock)
      expectToggleButtonHidden(rightDock)
      expectToggleButtonVisible(bottomDock, 'icon-chevron-down')

      // Click the toggle button
      bottomDock.toggleButton.innerElement.click()
      expect(bottomDock.isVisible()).toBe(false)
      expectToggleButtonHidden(bottomDock)

      // Mouse to edge of the window
      moveMouse({clientX: 300, clientY: 290})
      expectToggleButtonHidden(leftDock)
      moveMouse({clientX: 300, clientY: 300})
      expectToggleButtonVisible(bottomDock, 'icon-chevron-up')

      // Click the toggle button again
      bottomDock.toggleButton.innerElement.click()
      expect(bottomDock.isVisible()).toBe(true)
      expectToggleButtonVisible(bottomDock, 'icon-chevron-down')
    })

    function moveMouse(coordinates) {
      window.dispatchEvent(new MouseEvent('mousemove', coordinates))
      advanceClock(100)
    }

    function expectToggleButtonHidden(dock) {
      expect(dock.toggleButton.element).not.toHaveClass('atom-dock-toggle-button-visible')
    }

    function expectToggleButtonVisible(dock, iconClass) {
      expect(dock.toggleButton.element).toHaveClass('atom-dock-toggle-button-visible')
      expect(dock.toggleButton.iconElement).toHaveClass(iconClass)
    }
  })

  describe('the scrollbar visibility class', () => {
    it('has a class based on the style of the scrollbar', () => {
      let observeCallback
      const scrollbarStyle = require('scrollbar-style')
      spyOn(scrollbarStyle, 'observePreferredScrollbarStyle').andCallFake(cb => {
        observeCallback = cb
        return new Disposable(() => {})
      })

      const workspaceElement = atom.workspace.getElement()
      observeCallback('legacy')
      expect(workspaceElement.className).toMatch('scrollbars-visible-always')

      observeCallback('overlay')
      expect(workspaceElement).toHaveClass('scrollbars-visible-when-scrolling')
    })
  })

  describe('editor font styling', () => {
    let editor, editorElement, workspaceElement

    beforeEach(async () => {
      await atom.workspace.open('sample.js')

      workspaceElement = atom.workspace.getElement()
      jasmine.attachToDOM(workspaceElement)
      editor = atom.workspace.getActiveTextEditor()
      editorElement = editor.getElement()
    })

    it("updates the font-size based on the 'editor.fontSize' config value", async () => {
      const initialCharWidth = editor.getDefaultCharWidth()
      expect(getComputedStyle(editorElement).fontSize).toBe(atom.config.get('editor.fontSize') + 'px')

      atom.config.set('editor.fontSize', atom.config.get('editor.fontSize') + 5)
      await editorElement.component.getNextUpdatePromise()
      expect(getComputedStyle(editorElement).fontSize).toBe(atom.config.get('editor.fontSize') + 'px')
      expect(editor.getDefaultCharWidth()).toBeGreaterThan(initialCharWidth)
    })

    it("updates the font-family based on the 'editor.fontFamily' config value", async () => {
      const initialCharWidth = editor.getDefaultCharWidth()
      let fontFamily = atom.config.get('editor.fontFamily')
      expect(getComputedStyle(editorElement).fontFamily).toBe(fontFamily)

      atom.config.set('editor.fontFamily', 'sans-serif')
      fontFamily = atom.config.get('editor.fontFamily')
      await editorElement.component.getNextUpdatePromise()
      expect(getComputedStyle(editorElement).fontFamily).toBe(fontFamily)
      expect(editor.getDefaultCharWidth()).not.toBe(initialCharWidth)
    })

    it("updates the line-height based on the 'editor.lineHeight' config value", async () => {
      const initialLineHeight = editor.getLineHeightInPixels()
      atom.config.set('editor.lineHeight', '30px')
      await editorElement.component.getNextUpdatePromise()
      expect(getComputedStyle(editorElement).lineHeight).toBe(atom.config.get('editor.lineHeight'))
      expect(editor.getLineHeightInPixels()).not.toBe(initialLineHeight)
    })

    it('increases or decreases the font size when a ctrl-mousewheel event occurs', () => {
      atom.config.set('editor.zoomFontWhenCtrlScrolling', true)
      atom.config.set('editor.fontSize', 12)

      // Zoom out
      editorElement.querySelector('span').dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaY: -10,
        ctrlKey: true
      }))
      expect(atom.config.get('editor.fontSize')).toBe(11)

      // Zoom in
      editorElement.querySelector('span').dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaY: 10,
        ctrlKey: true
      }))
      expect(atom.config.get('editor.fontSize')).toBe(12)

      // Not on an atom-text-editor
      workspaceElement.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaY: 10,
        ctrlKey: true
      }))
      expect(atom.config.get('editor.fontSize')).toBe(12)

      // No ctrl key
      editorElement.querySelector('span').dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaY: 10
      }))
      expect(atom.config.get('editor.fontSize')).toBe(12)

      atom.config.set('editor.zoomFontWhenCtrlScrolling', false)
      editorElement.querySelector('span').dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaY: 10,
        ctrlKey: true
      }))
      expect(atom.config.get('editor.fontSize')).toBe(12)
    })
  })

  describe('panel containers', () => {
    it('inserts panel container elements in the correct places in the DOM', () => {
      const workspaceElement = atom.workspace.getElement()

      const leftContainer = workspaceElement.querySelector('atom-panel-container.left')
      const rightContainer = workspaceElement.querySelector('atom-panel-container.right')
      expect(leftContainer.nextSibling).toBe(workspaceElement.verticalAxis)
      expect(rightContainer.previousSibling).toBe(workspaceElement.verticalAxis)

      const topContainer = workspaceElement.querySelector('atom-panel-container.top')
      const bottomContainer = workspaceElement.querySelector('atom-panel-container.bottom')
      expect(topContainer.nextSibling).toBe(workspaceElement.paneContainer)
      expect(bottomContainer.previousSibling).toBe(workspaceElement.paneContainer)

      const headerContainer = workspaceElement.querySelector('atom-panel-container.header')
      const footerContainer = workspaceElement.querySelector('atom-panel-container.footer')
      expect(headerContainer.nextSibling).toBe(workspaceElement.horizontalAxis)
      expect(footerContainer.previousSibling).toBe(workspaceElement.horizontalAxis)

      const modalContainer = workspaceElement.querySelector('atom-panel-container.modal')
      expect(modalContainer.parentNode).toBe(workspaceElement)
    })

    it('stretches header/footer panels to the workspace width', () => {
      const workspaceElement = atom.workspace.getElement()
      jasmine.attachToDOM(workspaceElement)
      expect(workspaceElement.offsetWidth).toBeGreaterThan(0)

      const headerItem = document.createElement('div')
      atom.workspace.addHeaderPanel({item: headerItem})
      expect(headerItem.offsetWidth).toEqual(workspaceElement.offsetWidth)

      const footerItem = document.createElement('div')
      atom.workspace.addFooterPanel({item: footerItem})
      expect(footerItem.offsetWidth).toEqual(workspaceElement.offsetWidth)
    })

    it('shrinks horizontal axis according to header/footer panels height', () => {
      const workspaceElement = atom.workspace.getElement()
      workspaceElement.style.height = '100px'
      const horizontalAxisElement = workspaceElement.querySelector('atom-workspace-axis.horizontal')
      jasmine.attachToDOM(workspaceElement)

      const originalHorizontalAxisHeight = horizontalAxisElement.offsetHeight
      expect(workspaceElement.offsetHeight).toBeGreaterThan(0)
      expect(originalHorizontalAxisHeight).toBeGreaterThan(0)

      const headerItem = document.createElement('div')
      headerItem.style.height = '10px'
      atom.workspace.addHeaderPanel({item: headerItem})
      expect(headerItem.offsetHeight).toBeGreaterThan(0)

      const footerItem = document.createElement('div')
      footerItem.style.height = '15px'
      atom.workspace.addFooterPanel({item: footerItem})
      expect(footerItem.offsetHeight).toBeGreaterThan(0)

      expect(horizontalAxisElement.offsetHeight).toEqual(originalHorizontalAxisHeight - headerItem.offsetHeight - footerItem.offsetHeight)
    })
  })

  describe("the 'window:toggle-invisibles' command", () => {
    it('shows/hides invisibles in all open and future editors', () => {
      const workspaceElement = atom.workspace.getElement()
      expect(atom.config.get('editor.showInvisibles')).toBe(false)
      atom.commands.dispatch(workspaceElement, 'window:toggle-invisibles')
      expect(atom.config.get('editor.showInvisibles')).toBe(true)
      atom.commands.dispatch(workspaceElement, 'window:toggle-invisibles')
      expect(atom.config.get('editor.showInvisibles')).toBe(false)
    })
  })

  describe("the 'window:run-package-specs' command", () => {
    it("runs the package specs for the active item's project path, or the first project path", () => {
      const workspaceElement = atom.workspace.getElement()
      spyOn(ipcRenderer, 'send')

      // No project paths. Don't try to run specs.
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs')
      expect(ipcRenderer.send).not.toHaveBeenCalledWith('run-package-specs')

      const projectPaths = [temp.mkdirSync('dir1-'), temp.mkdirSync('dir2-')]
      atom.project.setPaths(projectPaths)

      // No active item. Use first project directory.
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs')
      expect(ipcRenderer.send).toHaveBeenCalledWith('run-package-specs', path.join(projectPaths[0], 'spec'))
      ipcRenderer.send.reset()

      // Active item doesn't implement ::getPath(). Use first project directory.
      const item = document.createElement('div')
      atom.workspace.getActivePane().activateItem(item)
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs')
      expect(ipcRenderer.send).toHaveBeenCalledWith('run-package-specs', path.join(projectPaths[0], 'spec'))
      ipcRenderer.send.reset()

      // Active item has no path. Use first project directory.
      item.getPath = () => null
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs')
      expect(ipcRenderer.send).toHaveBeenCalledWith('run-package-specs', path.join(projectPaths[0], 'spec'))
      ipcRenderer.send.reset()

      // Active item has path. Use project path for item path.
      item.getPath = () => path.join(projectPaths[1], 'a-file.txt')
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs')
      expect(ipcRenderer.send).toHaveBeenCalledWith('run-package-specs', path.join(projectPaths[1], 'spec'))
      ipcRenderer.send.reset()
    })
  })
})
