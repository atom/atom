$ = require 'jquery'
RootView = require 'root-view'
StatusBar = require 'status-bar'

describe "StatusBar", ->
  [rootView, editor, statusBar, buffer] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.simulateDomAttachment()
    StatusBar.activate(rootView)
    editor = rootView.getActiveEditor()
    statusBar = rootView.find('.status-bar').view()
    buffer = editor.getBuffer()

  afterEach ->
    rootView.remove()

  describe "@initialize", ->
    it "appends a status bar to all existing and new editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 1
      editor.splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 2

  describe ".initialize(editor)", ->
    it "displays the editor's buffer path, cursor buffer position, and buffer modified indicator", ->
      expect(statusBar.currentPath.text()).toBe 'sample.js'
      expect(statusBar.bufferModified.text()).toBe ''
      expect(statusBar.cursorPosition.text()).toBe '1,1'

    describe "when associated with an unsaved buffer", ->
      it "displays 'untitled' instead of the buffer's path, but still displays the buffer position", ->
        rootView.remove()
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

  describe "when the associated editor's buffer's content changes", ->
    it "enables the buffer modified indicator", ->
      expect(statusBar.bufferModified.text()).toBe ''
      editor.insertText("\n")
      expect(statusBar.bufferModified.text()).toBe '*'
      editor.backspace()

  describe "when the buffer content has changed from the content on disk", ->
    it "disables the buffer modified indicator on save", ->
      editor.insertText("\n")
      editor.save()
      expect(statusBar.bufferModified.text()).toBe ''
      editor.backspace()
      editor.save()

    it "disables the buffer modified indicator if the content matches again", ->
      editor.insertText("\n")
      expect(statusBar.bufferModified.text()).toBe '*'
      editor.backspace()
      expect(statusBar.bufferModified.text()).toBe ''

  describe "when the associated editor's cursor position changes", ->
    it "updates the cursor position in the status bar", ->
      editor.setCursorScreenPosition([1, 2])
      expect(statusBar.cursorPosition.text()).toBe '2,3'
