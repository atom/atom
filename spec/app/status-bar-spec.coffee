$ = require 'jquery'
RootView = require 'root-view'
StatusBar = require 'status-bar'

fdescribe "StatusBar", ->
  [rootView, statusBar] = []

  beforeEach ->
    rootView = new RootView(pathToOpen: require.resolve('fixtures/sample.js'))
    rootView.simulateDomAttachment()
    StatusBar.activate(rootView)
    statusBar = rootView.find('.status-bar').view()

  describe "@initialize", ->
    it "appends a status bar to all existing and new editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 1
      rootView.activeEditor().splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 2

  describe ".initialize(editor)", ->
    it "displays the editor's buffer path and cursor buffer position", ->
      expect(statusBar.currentPath.text()).toBe 'sample.js'
      expect(statusBar.cursorPosition.text()).toBe '0,0'

    describe "when associated with an unsaved buffer", ->
      it "displays 'untitled' instead of the buffer's path, but still displays the buffer position", ->
        rootView = new RootView
        rootView.simulateDomAttachment()
        StatusBar.activate(rootView)
        statusBar = rootView.find('.status-bar').view()
        expect(statusBar.currentPath.text()).toBe 'untitled'
        expect(statusBar.cursorPosition.text()).toBe '0,0'
