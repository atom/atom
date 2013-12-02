{$, $$, fs, WorkspaceView, View} = require 'atom'
Workspace = require '../src/workspace'
Q = require 'q'
path = require 'path'
temp = require 'temp'
Pane = require '../src/pane'

describe "WorkspaceView", ->
  [project, workspace, pathToOpen] = []

  beforeEach ->
    atom.project.setPath(atom.project.resolve('dir'))
    pathToOpen = atom.project.resolve('a')
    workspace = atom.project.createOrphan(new Workspace(project: atom.project))
    atom.workspaceView = new WorkspaceView(workspace)
    atom.workspaceView.enableKeymap()
    atom.workspaceView.openSync(pathToOpen)
    atom.workspaceView.focus()

  describe "focus", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    describe "when there is an active view", ->
      it "hands off focus to the active view", ->
        editorView = atom.workspaceView.getActiveView()
        editorView.isFocused = false
        atom.workspaceView.focus()
        expect(editorView.isFocused).toBeTruthy()

    describe "when there is no active view", ->
      beforeEach ->
        atom.workspaceView.getActivePane().remove()
        expect(atom.workspaceView.getActiveView()).toBeUndefined()
        atom.workspaceView.attachToDom()
        expect(document.activeElement).toBe document.body

      describe "when are visible focusable elements (with a -1 tabindex)", ->
        it "passes focus to the first focusable element", ->
          focusable1 = $$ -> @div "One", id: 'one', tabindex: -1
          focusable2 = $$ -> @div "Two", id: 'two', tabindex: -1
          atom.workspaceView.horizontal.append(focusable1, focusable2)
          expect(document.activeElement).toBe document.body

          atom.workspaceView.focus()
          expect(document.activeElement).toBe focusable1[0]

      describe "when there are no visible focusable elements", ->
        it "surrenders focus to the body", ->
          focusable = $$ -> @div "One", id: 'one', tabindex: -1
          atom.workspaceView.horizontal.append(focusable)
          focusable.hide()
          expect(document.activeElement).toBe document.body

          atom.workspaceView.focus()
          expect(document.activeElement).toBe document.body

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
        workspaceView2 = atom.deserializers.deserialize(atom.workspaceView.serialize())
        item = atom.workspaceView.getActivePaneItem()
        expect(workspaceView2.title).toBe "#{item.getTitle()} - #{atom.project.getPath()}"
        workspaceView2.remove()

  describe "font size adjustment", ->
    it "increases/decreases font size when increase/decrease-font-size events are triggered", ->
      fontSizeBefore = atom.config.get('editor.fontSize')
      atom.workspaceView.trigger 'window:increase-font-size'
      expect(atom.config.get('editor.fontSize')).toBe fontSizeBefore + 1
      atom.workspaceView.trigger 'window:increase-font-size'
      expect(atom.config.get('editor.fontSize')).toBe fontSizeBefore + 2
      atom.workspaceView.trigger 'window:decrease-font-size'
      expect(atom.config.get('editor.fontSize')).toBe fontSizeBefore + 1
      atom.workspaceView.trigger 'window:decrease-font-size'
      expect(atom.config.get('editor.fontSize')).toBe fontSizeBefore

    it "does not allow the font size to be less than 1", ->
      atom.config.set("editor.fontSize", 1)
      atom.workspaceView.trigger 'window:decrease-font-size'
      expect(atom.config.get('editor.fontSize')).toBe 1

  describe "window:toggle-invisibles event", ->
    it "shows/hides invisibles in all open and future editors", ->
      atom.workspaceView.height(200)
      atom.workspaceView.attachToDom()
      rightEditor = atom.workspaceView.getActiveView()
      rightEditor.setText(" \t ")
      leftEditor = rightEditor.splitLeft()
      expect(rightEditor.find(".line:first").text()).toBe "    "
      expect(leftEditor.find(".line:first").text()).toBe "    "

      withInvisiblesShowing = "#{rightEditor.invisibles.space}#{rightEditor.invisibles.tab} #{rightEditor.invisibles.space}#{rightEditor.invisibles.eol}"

      atom.workspaceView.trigger "window:toggle-invisibles"
      expect(rightEditor.find(".line:first").text()).toBe withInvisiblesShowing
      expect(leftEditor.find(".line:first").text()).toBe withInvisiblesShowing

      lowerLeftEditor = leftEditor.splitDown()
      expect(lowerLeftEditor.find(".line:first").text()).toBe withInvisiblesShowing

      atom.workspaceView.trigger "window:toggle-invisibles"
      expect(rightEditor.find(".line:first").text()).toBe "    "
      expect(leftEditor.find(".line:first").text()).toBe "    "

      lowerRightEditor = rightEditor.splitDown()
      expect(lowerRightEditor.find(".line:first").text()).toBe "    "

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
