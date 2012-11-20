$ = require 'jquery'
_ = require 'underscore'
RootView = require 'root-view'
Tabs = require 'tabs'

fdescribe "Tabs", ->
  [rootView, editor, statusBar, buffer, tabs] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.open('sample.txt')
    rootView.simulateDomAttachment()
    rootView.activateExtension(Tabs)
    editor = rootView.getActiveEditor()
    tabs = rootView.find('.tabs').view()

  afterEach ->
    rootView.remove()

  describe "@activate", ->
    it "appends a status bear to all existing and new editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .tabs').length).toBe 1
      editor.splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .tabs').length).toBe 2

  describe "#initialize()", ->
    it "creates a tab for each edit session on the editor to which the tab-strip belongs", ->
      expect(editor.editSessions.length).toBe 2
      expect(tabs.find('.tab').length).toBe 2

      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe editor.editSessions[0].buffer.getBaseName()
      expect(tabs.find('.tab:eq(1) .file-name').text()).toBe editor.editSessions[1].buffer.getBaseName()

    it "highlights the tab for the current active edit session", ->
      expect(editor.getActiveEditSessionIndex()).toBe 1
      expect(tabs.find('.tab:eq(1)')).toHaveClass 'active'

  describe "when the active edit session changes", ->
    it "highlights the tab for the newly-active edit session", ->
      editor.setActiveEditSessionIndex(0)
      expect(tabs.find('.active').length).toBe 1
      expect(tabs.find('.tab:eq(0)')).toHaveClass 'active'

      editor.setActiveEditSessionIndex(1)
      expect(tabs.find('.active').length).toBe 1
      expect(tabs.find('.tab:eq(1)')).toHaveClass 'active'

  describe "when a new edit session is created", ->
    it "adds a tab for the new edit session", ->
      rootView.open('two-hundred.txt')
      expect(tabs.find('.tab').length).toBe 3
      expect(tabs.find('.tab:eq(2) .file-name').text()).toBe 'two-hundred.txt'

  describe "when an edit session is removed", ->
    it "removes the tab for the removed edit session", ->
      editor.setActiveEditSessionIndex(0)
      editor.destroyActiveEditSession()
      expect(tabs.find('.tab').length).toBe 1
      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe 'sample.txt'
