'use strict'

/* global getComputedStyle, WheelEvent */

const {ipcRenderer} = require('electron')
const path = require('path')
const temp = require('temp').track()
const {Disposable} = require('event-kit')

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

    beforeEach(() => {
      waitsForPromise(() => atom.workspace.open('sample.js'))

      runs(() => {
        workspaceElement = atom.workspace.getElement()
        jasmine.attachToDOM(workspaceElement)
        editor = atom.workspace.getActiveTextEditor()
        editorElement = editor.getElement()
      })
    })

    it("updates the font-size based on the 'editor.fontSize' config value", () => {
      const initialCharWidth = editor.getDefaultCharWidth()
      expect(getComputedStyle(editorElement).fontSize).toBe(atom.config.get('editor.fontSize') + 'px')
      atom.config.set('editor.fontSize', atom.config.get('editor.fontSize') + 5)
      expect(getComputedStyle(editorElement).fontSize).toBe(atom.config.get('editor.fontSize') + 'px')
      expect(editor.getDefaultCharWidth()).toBeGreaterThan(initialCharWidth)
    })

    it("updates the font-family based on the 'editor.fontFamily' config value", () => {
      const initialCharWidth = editor.getDefaultCharWidth()
      let fontFamily = atom.config.get('editor.fontFamily')
      expect(getComputedStyle(editorElement).fontFamily).toBe(fontFamily)

      atom.config.set('editor.fontFamily', 'sans-serif')
      fontFamily = atom.config.get('editor.fontFamily')
      expect(getComputedStyle(editorElement).fontFamily).toBe(fontFamily)
      expect(editor.getDefaultCharWidth()).not.toBe(initialCharWidth)
    })

    it("updates the line-height based on the 'editor.lineHeight' config value", () => {
      const initialLineHeight = editor.getLineHeightInPixels()
      atom.config.set('editor.lineHeight', '30px')
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
