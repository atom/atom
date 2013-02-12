$ = require 'jquery'
_ = require 'underscore'
RootView = require 'root-view'
fs = require 'fs'

describe "TabView", ->
  [editor, buffer, tabs] = []

  beforeEach ->
    new RootView(require.resolve('fixtures/sample.js'))
    rootView.open('sample.txt')
    rootView.simulateDomAttachment()
    atom.loadPackage("tabs")
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

    it "sets the title on each tab to be the full path of the edit session", ->
      expect(tabs.find('.tab:eq(0) .file-name').attr('title')).toBe editor.editSessions[0].getPath()
      expect(tabs.find('.tab:eq(1) .file-name').attr('title')).toBe editor.editSessions[1].getPath()

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

    describe "when the edit session's buffer has an undefined path", ->
      it "makes the tab text 'untitled'", ->
        rootView.open()
        expect(tabs.find('.tab').length).toBe 3
        expect(tabs.find('.tab:eq(2) .file-name').text()).toBe 'untitled'

      it "removes the tab's title", ->
        rootView.open()
        expect(tabs.find('.tab').length).toBe 3
        expect(tabs.find('.tab:eq(2) .file-name').attr('title')).toBeUndefined()

  describe "when an edit session is removed", ->
    it "removes the tab for the removed edit session", ->
      editor.setActiveEditSessionIndex(0)
      editor.destroyActiveEditSession()
      expect(tabs.find('.tab').length).toBe 1
      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe 'sample.txt'

  describe "when a tab is clicked", ->
    it "activates the associated edit session", ->
      expect(editor.getActiveEditSessionIndex()).toBe 1
      tabs.find('.tab:eq(0)').click()
      expect(editor.getActiveEditSessionIndex()).toBe 0
      tabs.find('.tab:eq(1)').click()
      expect(editor.getActiveEditSessionIndex()).toBe 1

    it "focuses the associated editor", ->
      rootView.attachToDom()
      expect(editor).toMatchSelector ":has(:focus)"
      editor.splitRight()
      expect(editor).not.toMatchSelector ":has(:focus)"
      tabs.find('.tab:eq(0)').click()
      expect(editor).toMatchSelector ":has(:focus)"

  describe "when a file name associated with a tab changes", ->
    [buffer, oldPath, newPath] = []

    beforeEach ->
      buffer = editor.editSessions[0].buffer
      oldPath = "/tmp/file-to-rename.txt"
      newPath = "/tmp/renamed-file.txt"
      fs.write(oldPath, "this old path")
      rootView.open(oldPath)

    afterEach ->
      fs.remove(newPath) if fs.exists(newPath)

    it "updates the file name in the tab", ->
      tabFileName = tabs.find('.tab:eq(2) .file-name')
      expect(tabFileName).toExist()
      editor.setActiveEditSessionIndex(0)
      fs.move(oldPath, newPath)
      waitsFor "file to be renamed", ->
        tabFileName.text() == "renamed-file.txt"

  describe "when the close icon is clicked", ->
    it "closes the selected non-active edit session", ->
      activeSession = editor.activeEditSession
      expect(editor.getActiveEditSessionIndex()).toBe 1
      tabs.find('.tab .close-icon:eq(0)').click()
      expect(editor.getActiveEditSessionIndex()).toBe 0
      expect(editor.activeEditSession).toBe activeSession

    it "closes the selected active edit session", ->
      firstSession = editor.getEditSessions()[0]
      expect(editor.getActiveEditSessionIndex()).toBe 1
      tabs.find('.tab .close-icon:eq(1)').click()
      expect(editor.getActiveEditSessionIndex()).toBe 0
      expect(editor.activeEditSession).toBe firstSession

  describe "when two tabs have the same file name", ->
    [tempPath] = []

    beforeEach ->
      tempPath = '/tmp/sample.js'
      fs.write(tempPath, 'sample')

    afterEach ->
      fs.remove(tempPath) if fs.exists(tempPath)

    it "displays the parent folder name after the file name", ->
      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe 'sample.js'
      rootView.open(tempPath)
      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe 'sample.js - fixtures'
      expect(tabs.find('.tab:last .file-name').text()).toBe 'sample.js - tmp'
      editor.destroyActiveEditSession()
      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe 'sample.js'

  describe "when an editor:edit-session-order-changed event is triggered", ->
    it "updates the order of the tabs to match the new edit session order", ->
      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe "sample.js"
      expect(tabs.find('.tab:eq(1) .file-name').text()).toBe "sample.txt"

      editor.moveEditSessionToIndex(0, 1)
      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe "sample.txt"
      expect(tabs.find('.tab:eq(1) .file-name').text()).toBe "sample.js"

      editor.moveEditSessionToIndex(1, 0)
      expect(tabs.find('.tab:eq(0) .file-name').text()).toBe "sample.js"
      expect(tabs.find('.tab:eq(1) .file-name').text()).toBe "sample.txt"

  describe "dragging and dropping tabs", ->
    describe "when a tab is dragged from and dropped onto the same editor", ->
      it "moves the edit session and updates the order of the tabs", ->
        expect(tabs.find('.tab:eq(0) .file-name').text()).toBe "sample.js"
        expect(tabs.find('.tab:eq(1) .file-name').text()).toBe "sample.txt"

        sortableElement = [tabs.find('.tab:eq(0)')]
        spyOn(tabs, 'getSortableElement').andCallFake -> sortableElement[0]
        event = $.Event()
        event.target = tabs[0]
        event.originalEvent =
          dataTransfer:
            data: {}
            setData: (key, value) -> @data[key] = value
            getData: (key) -> @data[key]

        tabs.onDragStart(event)
        sortableElement = [tabs.find('.tab:eq(1)')]
        tabs.onDrop(event)

        expect(tabs.find('.tab:eq(0) .file-name').text()).toBe "sample.txt"
        expect(tabs.find('.tab:eq(1) .file-name').text()).toBe "sample.js"

    describe "when a tab is dragged from one editor and dropped onto another editor", ->
      it "moves the edit session and updates the order of the tabs", ->
        leftTabs = tabs
        editor.splitRight()
        rightTabs = rootView.find('.tabs:last').view()

        sortableElement = [leftTabs.find('.tab:eq(0)')]
        spyOn(tabs, 'getSortableElement').andCallFake -> sortableElement[0]
        event = $.Event()
        event.target = leftTabs
        event.originalEvent =
          dataTransfer:
            data: {}
            setData: (key, value) -> @data[key] = value
            getData: (key) -> @data[key]

        tabs.onDragStart(event)

        event.target = rightTabs
        sortableElement = [rightTabs.find('.tab:eq(0)')]
        tabs.onDrop(event)

        expect(rightTabs.find('.tab:eq(0) .file-name').text()).toBe "sample.txt"
        expect(rightTabs.find('.tab:eq(1) .file-name').text()).toBe "sample.js"
