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
    workspace = atom.project.create(new Workspace(project: atom.project))
    atom.workspaceView = new WorkspaceView(workspace)
    atom.workspaceView.enableKeymap()
    atom.workspaceView.openSync(pathToOpen)
    atom.workspaceView.focus()

  describe "::onEachEditorView", ->
    it "calls the given callback with all current and future editor views", ->
      editor1 = workspace.openSync('a')
      workspace.activePane.splitRight()
      editor2 = workspace.openSync('a')
      editor3 = workspace.openSync('b')

      editors = []
      atom.workspaceView.onEachEditorView (view) -> editors.push(view.model)

      expect(editors).toEqual [editor1, editor3]

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
