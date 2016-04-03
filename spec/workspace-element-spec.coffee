{ipcRenderer} = require 'electron'
path = require 'path'
temp = require('temp').track()

describe "WorkspaceElement", ->
  describe "when the workspace element is focused", ->
    it "transfers focus to the active pane", ->
      workspaceElement = atom.views.getView(atom.workspace)
      jasmine.attachToDOM(workspaceElement)
      activePaneElement = atom.views.getView(atom.workspace.getActivePane())
      document.body.focus()
      expect(document.activeElement).not.toBe(activePaneElement)
      workspaceElement.focus()
      expect(document.activeElement).toBe(activePaneElement)

  describe "the scrollbar visibility class", ->
    it "has a class based on the style of the scrollbar", ->
      observeCallback = null
      scrollbarStyle = require 'scrollbar-style'
      spyOn(scrollbarStyle, 'observePreferredScrollbarStyle').andCallFake (cb) -> observeCallback = cb
      workspaceElement = atom.views.getView(atom.workspace)

      observeCallback('legacy')
      expect(workspaceElement.className).toMatch 'scrollbars-visible-always'

      observeCallback('overlay')
      expect(workspaceElement).toHaveClass 'scrollbars-visible-when-scrolling'

  describe "editor font styling", ->
    [editor, editorElement] = []

    beforeEach ->
      waitsForPromise -> atom.workspace.open('sample.js')

      runs ->
        workspaceElement = atom.views.getView(atom.workspace)
        jasmine.attachToDOM(workspaceElement)
        editor = atom.workspace.getActiveTextEditor()
        editorElement = atom.views.getView(editor)

    it "updates the font-size based on the 'editor.fontSize' config value", ->
      initialCharWidth = editor.getDefaultCharWidth()
      expect(getComputedStyle(editorElement).fontSize).toBe atom.config.get('editor.fontSize') + 'px'
      atom.config.set('editor.fontSize', atom.config.get('editor.fontSize') + 5)
      expect(getComputedStyle(editorElement).fontSize).toBe atom.config.get('editor.fontSize') + 'px'
      expect(editor.getDefaultCharWidth()).toBeGreaterThan initialCharWidth

    it "updates the font-family based on the 'editor.fontFamily' config value", ->
      initialCharWidth = editor.getDefaultCharWidth()
      fontFamily = atom.config.get('editor.fontFamily')
      fontFamily += ", 'Apple Color Emoji'" if process.platform is 'darwin'
      expect(getComputedStyle(editorElement).fontFamily).toBe fontFamily

      atom.config.set('editor.fontFamily', 'sans-serif')
      fontFamily = atom.config.get('editor.fontFamily')
      fontFamily += ", 'Apple Color Emoji'" if process.platform is 'darwin'
      expect(getComputedStyle(editorElement).fontFamily).toBe fontFamily
      expect(editor.getDefaultCharWidth()).not.toBe initialCharWidth

    it "updates the line-height based on the 'editor.lineHeight' config value", ->
      initialLineHeight = editor.getLineHeightInPixels()
      atom.config.set('editor.lineHeight', '30px')
      expect(getComputedStyle(editorElement).lineHeight).toBe atom.config.get('editor.lineHeight')
      expect(editor.getLineHeightInPixels()).not.toBe initialLineHeight

  describe 'panel containers', ->
    it 'inserts panel container elements in the correct places in the DOM', ->
      workspaceElement = atom.views.getView(atom.workspace)

      leftContainer = workspaceElement.querySelector('atom-panel-container.left')
      rightContainer = workspaceElement.querySelector('atom-panel-container.right')
      expect(leftContainer.nextSibling).toBe workspaceElement.verticalAxis
      expect(rightContainer.previousSibling).toBe workspaceElement.verticalAxis

      topContainer = workspaceElement.querySelector('atom-panel-container.top')
      bottomContainer = workspaceElement.querySelector('atom-panel-container.bottom')
      expect(topContainer.nextSibling).toBe workspaceElement.paneContainer
      expect(bottomContainer.previousSibling).toBe workspaceElement.paneContainer

      headerContainer = workspaceElement.querySelector('atom-panel-container.header')
      footerContainer = workspaceElement.querySelector('atom-panel-container.footer')
      expect(headerContainer.nextSibling).toBe workspaceElement.horizontalAxis
      expect(footerContainer.previousSibling).toBe workspaceElement.horizontalAxis

      modalContainer = workspaceElement.querySelector('atom-panel-container.modal')
      expect(modalContainer.parentNode).toBe workspaceElement

    it 'stretches header/footer panels to the workspace width', ->
      workspaceElement = atom.views.getView(atom.workspace)
      jasmine.attachToDOM(workspaceElement)
      expect(workspaceElement.offsetWidth).toBeGreaterThan(0)

      headerItem = document.createElement('div')
      atom.workspace.addHeaderPanel({item: headerItem})
      expect(headerItem.offsetWidth).toEqual(workspaceElement.offsetWidth)

      footerItem = document.createElement('div')
      atom.workspace.addFooterPanel({item: footerItem})
      expect(footerItem.offsetWidth).toEqual(workspaceElement.offsetWidth)

    it 'shrinks horizontal axis according to header/footer panels height', ->
      workspaceElement = atom.views.getView(atom.workspace)
      workspaceElement.style.height = '100px'
      horizontalAxisElement = workspaceElement.querySelector('atom-workspace-axis.horizontal')
      jasmine.attachToDOM(workspaceElement)

      originalHorizontalAxisHeight = horizontalAxisElement.offsetHeight
      expect(workspaceElement.offsetHeight).toBeGreaterThan(0)
      expect(originalHorizontalAxisHeight).toBeGreaterThan(0)

      headerItem = document.createElement('div')
      headerItem.style.height = '10px'
      atom.workspace.addHeaderPanel({item: headerItem})
      expect(headerItem.offsetHeight).toBeGreaterThan(0)

      footerItem = document.createElement('div')
      footerItem.style.height = '15px'
      atom.workspace.addFooterPanel({item: footerItem})
      expect(footerItem.offsetHeight).toBeGreaterThan(0)

      expect(horizontalAxisElement.offsetHeight).toEqual(originalHorizontalAxisHeight - headerItem.offsetHeight - footerItem.offsetHeight)

  describe "the 'window:toggle-invisibles' command", ->
    it "shows/hides invisibles in all open and future editors", ->
      workspaceElement = atom.views.getView(atom.workspace)
      expect(atom.config.get('editor.showInvisibles')).toBe false
      atom.commands.dispatch(workspaceElement, 'window:toggle-invisibles')
      expect(atom.config.get('editor.showInvisibles')).toBe true
      atom.commands.dispatch(workspaceElement, 'window:toggle-invisibles')
      expect(atom.config.get('editor.showInvisibles')).toBe false

  describe "the 'window:run-package-specs' command", ->
    it "runs the package specs for the active item's project path, or the first project path", ->
      workspaceElement = atom.views.getView(atom.workspace)
      spyOn(ipcRenderer, 'send')

      # No project paths. Don't try to run specs.
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipcRenderer.send).not.toHaveBeenCalledWith("run-package-specs")

      projectPaths = [temp.mkdirSync("dir1-"), temp.mkdirSync("dir2-")]
      atom.project.setPaths(projectPaths)

      # No active item. Use first project directory.
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipcRenderer.send).toHaveBeenCalledWith("run-package-specs", path.join(projectPaths[0], "spec"))
      ipcRenderer.send.reset()

      # Active item doesn't implement ::getPath(). Use first project directory.
      item = document.createElement("div")
      atom.workspace.getActivePane().activateItem(item)
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipcRenderer.send).toHaveBeenCalledWith("run-package-specs", path.join(projectPaths[0], "spec"))
      ipcRenderer.send.reset()

      # Active item has no path. Use first project directory.
      item.getPath = -> null
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipcRenderer.send).toHaveBeenCalledWith("run-package-specs", path.join(projectPaths[0], "spec"))
      ipcRenderer.send.reset()

      # Active item has path. Use project path for item path.
      item.getPath = -> path.join(projectPaths[1], "a-file.txt")
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipcRenderer.send).toHaveBeenCalledWith("run-package-specs", path.join(projectPaths[1], "spec"))
      ipcRenderer.send.reset()
