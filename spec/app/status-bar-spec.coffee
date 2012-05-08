$ = require 'jquery'
RootView = require 'root-view'
StatusBar = require 'status-bar'

describe "StatusBar", ->
  [rootView, editor, statusBar] = []

  beforeEach ->
    rootView = new RootView(pathToOpen: require.resolve('fixtures/sample.js'))
    rootView.simulateDomAttachment()
    StatusBar.activate(rootView)
    editor = rootView.activeEditor()
    statusBar = rootView.find('.status-bar').view()

  describe "@initialize", ->
    it "appends a status bar to all existing and new editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 1
      editor.splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 2

  describe ".initialize(editor)", ->
    it "displays the editor's buffer path and cursor buffer position", ->
      expect(statusBar.currentPath.text()).toBe 'sample.js'
      expect(statusBar.cursorPosition.text()).toBe '1,1'

    describe "when associated with an unsaved buffer", ->
      it "displays 'untitled' instead of the buffer's path, but still displays the buffer position", ->
        rootView = new RootView
        rootView.open()
        rootView.simulateDomAttachment()
        StatusBar.activate(rootView)
        statusBar = rootView.find('.status-bar').view()
        expect(statusBar.currentPath.text()).toBe 'untitled'
        expect(statusBar.cursorPosition.text()).toBe '1,1'

  describe "when the associated editor's path changes", ->
    it "updates the path in the status bar", ->
      rootView.open(require.resolve 'fixtures/sample.txt')
      expect(statusBar.currentPath.text()).toBe 'sample.txt'

  describe "when the associated editor's cursor position changes", ->
    it "updates the cursor position in the status bar", ->
      editor.setCursorScreenPosition([1, 2])
      expect(statusBar.cursorPosition.text()).toBe '2,3'
