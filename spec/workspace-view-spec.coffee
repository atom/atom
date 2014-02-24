{$, $$, WorkspaceView, View} = require 'atom'
Q = require 'q'
path = require 'path'
temp = require 'temp'
PaneView = require '../src/pane-view'
Workspace = require '../src/workspace'

describe "WorkspaceView", ->
  pathToOpen = null

  beforeEach ->
    atom.project.setPath(atom.project.resolve('dir'))
    pathToOpen = atom.project.resolve('a')
    atom.workspace = new Workspace
    atom.workspaceView = new WorkspaceView(atom.workspace)
    atom.workspaceView.enableKeymap()
    atom.workspaceView.openSync(pathToOpen)
    atom.workspaceView.focus()

  describe "@deserialize()", ->
    viewState = null

    simulateReload = ->
      workspaceState = atom.workspace.serialize()
      projectState = atom.project.serialize()
      atom.workspaceView.remove()
      atom.project = atom.deserializers.deserialize(projectState)
      atom.workspace = Workspace.deserialize(workspaceState)
      atom.workspaceView = new WorkspaceView(atom.workspace)
      atom.workspaceView.attachToDom()

    describe "when the serialized WorkspaceView has an unsaved buffer", ->
      it "constructs the view with the same panes", ->
        atom.workspaceView.attachToDom()
        atom.workspaceView.openSync()
        editorView1 = atom.workspaceView.getActiveView()
        buffer = editorView1.getEditor().getBuffer()
        editorView1.splitRight()
        expect(atom.workspaceView.getActivePane()).toBe atom.workspaceView.getPaneViews()[1]

        simulateReload()

        expect(atom.workspaceView.getEditorViews().length).toBe 2
        expect(atom.workspaceView.getActivePane()).toBe atom.workspaceView.getPaneViews()[1]
        expect(atom.workspaceView.title).toBe "untitled - #{atom.project.getPath()}"

    describe "when there are open editors", ->
      it "constructs the view with the same panes", ->
        atom.workspaceView.attachToDom()
        pane1 = atom.workspaceView.getActivePane()
        pane2 = pane1.splitRight()
        pane3 = pane2.splitRight()
        pane4 = pane2.splitDown()
        pane2.activateItem(atom.project.openSync('b'))
        pane3.activateItem(atom.project.openSync('../sample.js'))
        pane3.activeItem.setCursorScreenPosition([2, 4])
        pane4.activateItem(atom.project.openSync('../sample.txt'))
        pane4.activeItem.setCursorScreenPosition([0, 2])
        pane2.focus()

        simulateReload()

        expect(atom.workspaceView.getEditorViews().length).toBe 4
        editorView1 = atom.workspaceView.panes.find('.pane-row > .pane .editor:eq(0)').view()
        editorView3 = atom.workspaceView.panes.find('.pane-row > .pane .editor:eq(1)').view()
        editorView2 = atom.workspaceView.panes.find('.pane-row > .pane-column > .pane .editor:eq(0)').view()
        editorView4 = atom.workspaceView.panes.find('.pane-row > .pane-column > .pane .editor:eq(1)').view()

        expect(editorView1.getEditor().getPath()).toBe atom.project.resolve('a')
        expect(editorView2.getEditor().getPath()).toBe atom.project.resolve('b')
        expect(editorView3.getEditor().getPath()).toBe atom.project.resolve('../sample.js')
        expect(editorView3.getEditor().getCursorScreenPosition()).toEqual [2, 4]
        expect(editorView4.getEditor().getPath()).toBe atom.project.resolve('../sample.txt')
        expect(editorView4.getEditor().getCursorScreenPosition()).toEqual [0, 2]

        # ensure adjust pane dimensions is called
        expect(editorView1.width()).toBeGreaterThan 0
        expect(editorView2.width()).toBeGreaterThan 0
        expect(editorView3.width()).toBeGreaterThan 0
        expect(editorView4.width()).toBeGreaterThan 0

        # ensure correct editorView is focused again
        expect(editorView2.isFocused).toBeTruthy()
        expect(editorView1.isFocused).toBeFalsy()
        expect(editorView3.isFocused).toBeFalsy()
        expect(editorView4.isFocused).toBeFalsy()

        expect(atom.workspaceView.title).toBe "#{path.basename(editorView2.getEditor().getPath())} - #{atom.project.getPath()}"

    describe "where there are no open editors", ->
      it "constructs the view with no open editors", ->
        atom.workspaceView.getActivePane().remove()
        expect(atom.workspaceView.getEditorViews().length).toBe 0
        simulateReload()
        expect(atom.workspaceView.getEditorViews().length).toBe 0

  describe "focus", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "hands off focus to the active pane", ->
      activePane = atom.workspaceView.getActivePane()
      $('body').focus()
      expect(activePane.hasFocus()).toBe false
      atom.workspaceView.focus()
      expect(activePane.hasFocus()).toBe true

  describe "keymap wiring", ->
    commandHandler = null
    beforeEach ->
      commandHandler = jasmine.createSpy('commandHandler')
      atom.workspaceView.on('foo-command', commandHandler)

      atom.keymap.bindKeys('name', '*', 'x': 'foo-command')

    describe "when a keydown event is triggered in the WorkspaceView", ->
      it "triggers matching keybindings for that event", ->
        event = keydownEvent 'x', target: atom.workspaceView[0]

        atom.workspaceView.trigger(event)
        expect(commandHandler).toHaveBeenCalled()

  describe "window title", ->
    describe "when the project has no path", ->
      it "sets the title to 'untitled'", ->
        atom.project.setPath(undefined)
        expect(atom.workspaceView.title).toBe 'untitled'

    describe "when the project has a path", ->
      beforeEach ->
        atom.workspaceView.openSync('b')

      describe "when there is an active pane item", ->
        it "sets the title to the pane item's title plus the project path", ->
          item = atom.workspaceView.getActivePaneItem()
          expect(atom.workspaceView.title).toBe "#{item.getTitle()} - #{atom.project.getPath()}"

      describe "when the title of the active pane item changes", ->
        it "updates the window title based on the item's new title", ->
          editor = atom.workspaceView.getActivePaneItem()
          editor.buffer.setPath(path.join(temp.dir, 'hi'))
          expect(atom.workspaceView.title).toBe "#{editor.getTitle()} - #{atom.project.getPath()}"

      describe "when the active pane's item changes", ->
        it "updates the title to the new item's title plus the project path", ->
          atom.workspaceView.getActivePane().showNextItem()
          item = atom.workspaceView.getActivePaneItem()
          expect(atom.workspaceView.title).toBe "#{item.getTitle()} - #{atom.project.getPath()}"

      describe "when the last pane item is removed", ->
        it "updates the title to contain the project's path", ->
          atom.workspaceView.getActivePane().remove()
          expect(atom.workspaceView.getActivePaneItem()).toBeUndefined()
          expect(atom.workspaceView.title).toBe atom.project.getPath()

      describe "when an inactive pane's item changes", ->
        it "does not update the title", ->
          pane = atom.workspaceView.getActivePane()
          pane.splitRight()
          initialTitle = atom.workspaceView.title
          pane.showNextItem()
          expect(atom.workspaceView.title).toBe initialTitle

    describe "when the root view is deserialized", ->
      it "updates the title to contain the project's path", ->
        workspaceView2 = new WorkspaceView(atom.workspace.testSerialization())
        item = atom.workspaceView.getActivePaneItem()
        expect(workspaceView2.title).toBe "#{item.getTitle()} - #{atom.project.getPath()}"
        workspaceView2.remove()

  describe "window:toggle-invisibles event", ->
    it "shows/hides invisibles in all open and future editors", ->
      atom.workspaceView.height(200)
      atom.workspaceView.attachToDom()
      rightEditorView = atom.workspaceView.getActiveView()
      rightEditorView.getEditor().setText(" \t ")
      leftEditorView = rightEditorView.splitLeft()
      expect(rightEditorView.find(".line:first").text()).toBe "    "
      expect(leftEditorView.find(".line:first").text()).toBe "    "

      withInvisiblesShowing = "#{rightEditorView.invisibles.space}#{rightEditorView.invisibles.tab} #{rightEditorView.invisibles.space}#{rightEditorView.invisibles.eol}"

      atom.workspaceView.trigger "window:toggle-invisibles"
      expect(rightEditorView.find(".line:first").text()).toBe withInvisiblesShowing
      expect(leftEditorView.find(".line:first").text()).toBe withInvisiblesShowing

      lowerLeftEditorView = leftEditorView.splitDown()
      expect(lowerLeftEditorView.find(".line:first").text()).toBe withInvisiblesShowing

      atom.workspaceView.trigger "window:toggle-invisibles"
      expect(rightEditorView.find(".line:first").text()).toBe "    "
      expect(leftEditorView.find(".line:first").text()).toBe "    "

      lowerRightEditorView = rightEditorView.splitDown()
      expect(lowerRightEditorView.find(".line:first").text()).toBe "    "

  describe ".eachEditorView(callback)", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "invokes the callback for existing editor", ->
      count = 0
      callbackEditor = null
      callback = (editor) ->
        callbackEditor = editor
        count++
      atom.workspaceView.eachEditorView(callback)
      expect(count).toBe 1
      expect(callbackEditor).toBe atom.workspaceView.getActiveView()

    it "invokes the callback for new editor", ->
      count = 0
      callbackEditor = null
      callback = (editor) ->
        callbackEditor = editor
        count++

      atom.workspaceView.eachEditorView(callback)
      count = 0
      callbackEditor = null
      atom.workspaceView.getActiveView().splitRight()
      expect(count).toBe 1
      expect(callbackEditor).toBe atom.workspaceView.getActiveView()

    it "returns a subscription that can be disabled", ->
      count = 0
      callback = (editor) -> count++

      subscription = atom.workspaceView.eachEditorView(callback)
      expect(count).toBe 1
      atom.workspaceView.getActiveView().splitRight()
      expect(count).toBe 2
      subscription.off()
      atom.workspaceView.getActiveView().splitRight()
      expect(count).toBe 2

  describe "core:close", ->
    it "closes the active pane item until all that remains is a single empty pane", ->
      atom.config.set('core.destroyEmptyPanes', true)
      atom.project.openSync('../sample.txt')
      expect(atom.workspaceView.getActivePane().getItems()).toHaveLength 1
      atom.workspaceView.trigger('core:close')
      expect(atom.workspaceView.getActivePane().getItems()).toHaveLength 0
