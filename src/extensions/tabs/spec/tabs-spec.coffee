$ = require 'jquery'
_ = require 'underscore'
RootView = require 'root-view'
Tabs = require 'tabs'

describe "Tabs", ->
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
    fit "appends a status bear to all existing and new editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .tabs').length).toBe 1
      editor.splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .tabs').length).toBe 2

  describe "#initialize()", ->
    fit "creates a tab for each edit session on the editor to which the tab-strip belongs", ->
      expect(editor.editSessions.length).toBe 2
      expect(tabs.find('.tab').length).toBe 2

      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe editor.editSessions[0].buffer.getBaseName()
      expect(tabs.find('.tab:eq(1) .file-name').text()).toBe editor.editSessions[1].buffer.getBaseName()
