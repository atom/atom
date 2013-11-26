{$, $$, fs, WorkspaceView, View} = require 'atom'
Q = require 'q'
path = require 'path'
temp = require 'temp'
Pane = require '../src/pane'

describe "WorkspaceView", ->
  pathToOpen = null

  beforeEach ->
    atom.project.setPath(atom.project.resolve('dir'))
    pathToOpen = atom.project.resolve('a')
    atom.workspaceView = new WorkspaceView
    atom.workspaceView.enableKeymap()
    atom.workspaceView.openSync(pathToOpen)
    atom.workspaceView.focus()

  describe "@deserialize()", ->
    viewState = null

    refreshWorkspaceViewAndProject = ->
      workspaceViewState = atom.workspaceView.serialize()
      atom.project.getState().serializeForPersistence()
      project2 = atom.replicate().get('project')
      atom.workspaceView.remove()
      atom.project.destroy()
      atom.project = project2
      atom.workspaceView = atom.deserializers.deserialize(workspaceViewState)
      atom.workspaceView.attachToDom()

    describe "when the serialized WorkspaceView has an unsaved buffer", ->
      it "constructs the view with the same panes", ->
        atom.workspaceView.attachToDom()
        atom.workspaceView.openSync()
        editor1 = atom.workspaceView.getActiveView()
        buffer = editor1.getBuffer()
        editor1.splitRight()
        expect(atom.workspaceView.getActiveView()).toBe atom.workspaceView.getEditors()[2]

        refreshWorkspaceViewAndProject()

        expect(atom.workspaceView.getEditors().length).toBe 2
        expect(atom.workspaceView.getActiveView()).toBe atom.workspaceView.getEditors()[1]
        expect(atom.workspaceView.title).toBe "untitled - #{atom.project.getPath()}"

    describe "when there are open editors", ->
      it "constructs the view with the same panes", ->
        atom.workspaceView.attachToDom()
        pane1 = atom.workspaceView.getActivePane()
        pane2 = pane1.splitRight()
        pane3 = pane2.splitRight()
        pane4 = pane2.splitDown()
        pane2.showItem(atom.project.openSync('b'))
        pane3.showItem(atom.project.openSync('../sample.js'))
        pane3.activeItem.setCursorScreenPosition([2, 4])
        pane4.showItem(atom.project.openSync('../sample.txt'))
        pane4.activeItem.setCursorScreenPosition([0, 2])
        pane2.focus()

        refreshWorkspaceViewAndProject()

        expect(atom.workspaceView.getEditors().length).toBe 4
        editor1 = atom.workspaceView.panes.find('.row > .pane .editor:eq(0)').view()
        editor3 = atom.workspaceView.panes.find('.row > .pane .editor:eq(1)').view()
        editor2 = atom.workspaceView.panes.find('.row > .column > .pane .editor:eq(0)').view()
        editor4 = atom.workspaceView.panes.find('.row > .column > .pane .editor:eq(1)').view()

        expect(editor1.getPath()).toBe atom.project.resolve('a')
        expect(editor2.getPath()).toBe atom.project.resolve('b')
        expect(editor3.getPath()).toBe atom.project.resolve('../sample.js')
        expect(editor3.getCursorScreenPosition()).toEqual [2, 4]
        expect(editor4.getPath()).toBe atom.project.resolve('../sample.txt')
        expect(editor4.getCursorScreenPosition()).toEqual [0, 2]

        # ensure adjust pane dimensions is called
        expect(editor1.width()).toBeGreaterThan 0
        expect(editor2.width()).toBeGreaterThan 0
        expect(editor3.width()).toBeGreaterThan 0
        expect(editor4.width()).toBeGreaterThan 0

        # ensure correct editor is focused again
        expect(editor2.isFocused).toBeTruthy()
        expect(editor1.isFocused).toBeFalsy()
        expect(editor3.isFocused).toBeFalsy()
        expect(editor4.isFocused).toBeFalsy()

        expect(atom.workspaceView.title).toBe "#{path.basename(editor2.getPath())} - #{atom.project.getPath()}"

    describe "where there are no open editors", ->
      it "constructs the view with no open editors", ->
        atom.workspaceView.getActivePane().remove()
        expect(atom.workspaceView.getEditors().length).toBe 0
        refreshWorkspaceViewAndProject()
        expect(atom.workspaceView.getEditors().length).toBe 0

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

  describe ".openSync(filePath, options)", ->
    describe "when there is no active pane", ->
      beforeEach ->
        spyOn(Pane.prototype, 'focus')
        atom.workspaceView.getActivePane().remove()
        expect(atom.workspaceView.getActivePane()).toBeUndefined()

      describe "when called with no path", ->
        it "creates a empty edit session as an item on a new pane, and focuses the pane", ->
          editor = atom.workspaceView.openSync()
          expect(atom.workspaceView.getActivePane().activeItem).toBe editor
          expect(editor.getPath()).toBeUndefined()
          expect(atom.workspaceView.getActivePane().focus).toHaveBeenCalled()

        it "can create multiple empty edit sessions as an item on a new pane", ->
          editor = atom.workspaceView.openSync()
          editor2 = atom.workspaceView.openSync()
          expect(atom.workspaceView.getActivePane().getItems().length).toBe 2
          expect(editor).not.toBe editor2

      describe "when called with a path", ->
        it "creates an edit session for the given path as an item on a new pane, and focuses the pane", ->
          editor = atom.workspaceView.openSync('b')
          expect(atom.workspaceView.getActivePane().activeItem).toBe editor
          expect(editor.getPath()).toBe require.resolve('./fixtures/dir/b')
          expect(atom.workspaceView.getActivePane().focus).toHaveBeenCalled()

      describe "when the changeFocus option is false", ->
        it "does not focus the new pane", ->
          editor = atom.workspaceView.openSync('b', changeFocus: false)
          expect(atom.workspaceView.getActivePane().focus).not.toHaveBeenCalled()

      describe "when the split option is 'right'", ->
        it "creates a new pane and opens the file in said pane", ->
          editor = atom.workspaceView.openSync('b', split: 'right')
          expect(atom.workspaceView.getActivePane().activeItem).toBe editor
          expect(editor.getPath()).toBe require.resolve('./fixtures/dir/b')

    describe "when there is an active pane", ->
      [activePane, initialItemCount] = []
      beforeEach ->
        activePane = atom.workspaceView.getActivePane()
        spyOn(activePane, 'focus')
        initialItemCount = activePane.getItems().length

      describe "when called with no path", ->
        it "opens an edit session with an empty buffer as an item in the active pane and focuses it", ->
          editor = atom.workspaceView.openSync()
          expect(activePane.getItems().length).toBe initialItemCount + 1
          expect(activePane.activeItem).toBe editor
          expect(editor.getPath()).toBeUndefined()
          expect(activePane.focus).toHaveBeenCalled()

      describe "when called with a path", ->
        describe "when the active pane already has an edit session item for the path being opened", ->
          it "shows the existing edit session in the pane", ->
            previousEditor = activePane.activeItem

            editor = atom.workspaceView.openSync('b')
            expect(activePane.activeItem).toBe editor
            expect(editor).not.toBe previousEditor

            editor = atom.workspaceView.openSync(previousEditor.getPath())
            expect(editor).toBe previousEditor
            expect(activePane.activeItem).toBe editor

            expect(activePane.focus).toHaveBeenCalled()

        describe "when the active pane does not have an edit session item for the path being opened", ->
          it "creates a new edit session for the given path in the active editor", ->
            editor = atom.workspaceView.openSync('b')
            expect(activePane.items.length).toBe 2
            expect(activePane.activeItem).toBe editor
            expect(activePane.focus).toHaveBeenCalled()

      describe "when the changeFocus option is false", ->
        it "does not focus the active pane", ->
          editor = atom.workspaceView.openSync('b', changeFocus: false)
          expect(activePane.focus).not.toHaveBeenCalled()

      describe "when the split option is 'right'", ->
        it "creates a new pane and opens the file in said pane", ->
          pane1 = atom.workspaceView.getActivePane()

          editor = atom.workspaceView.openSync('b', split: 'right')
          pane2 = atom.workspaceView.getActivePane()
          expect(pane2[0]).not.toBe pane1[0]
          expect(editor.getPath()).toBe require.resolve('./fixtures/dir/b')

          expect(atom.workspaceView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

          editor = atom.workspaceView.openSync('file1', split: 'right')
          pane3 = atom.workspaceView.getActivePane()
          expect(pane3[0]).toBe pane2[0]
          expect(editor.getPath()).toBe require.resolve('./fixtures/dir/file1')

          expect(atom.workspaceView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

  describe ".openSingletonSync(filePath, options)", ->
    describe "when there is an active pane", ->
      [pane1] = []
      beforeEach ->
        spyOn(Pane.prototype, 'focus').andCallFake -> @makeActive()
        pane1 = atom.workspaceView.getActivePane()

      it "creates a new pane and reuses the file when already open", ->
        atom.workspaceView.openSingletonSync('b', split: 'right')
        pane2 = atom.workspaceView.getActivePane()
        expect(pane2[0]).not.toBe pane1[0]
        expect(pane1.itemForUri('b')).toBeFalsy()
        expect(pane2.itemForUri('b')).not.toBeFalsy()
        expect(atom.workspaceView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

        pane1.focus()
        expect(atom.workspaceView.getActivePane()[0]).toBe pane1[0]

        atom.workspaceView.openSingletonSync('b', split: 'right')
        pane3 = atom.workspaceView.getActivePane()
        expect(pane3[0]).toBe pane2[0]
        expect(pane1.itemForUri('b')).toBeFalsy()
        expect(pane2.itemForUri('b')).not.toBeFalsy()
        expect(atom.workspaceView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

      it "handles split: left by opening to the left pane when necessary", ->
        atom.workspaceView.openSingletonSync('b', split: 'right')
        pane2 = atom.workspaceView.getActivePane()
        expect(pane2[0]).not.toBe pane1[0]

        atom.workspaceView.openSingletonSync('file1', split: 'left')

        activePane = atom.workspaceView.getActivePane()
        expect(activePane[0]).toBe pane1[0]

        expect(pane1.itemForUri('file1')).toBeTruthy()
        expect(pane2.itemForUri('file1')).toBeFalsy()
        expect(atom.workspaceView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

        pane2.focus()
        expect(atom.workspaceView.getActivePane()[0]).toBe pane2[0]

        atom.workspaceView.openSingletonSync('file1', split: 'left')
        activePane = atom.workspaceView.getActivePane()
        expect(activePane[0]).toBe pane1[0]
        expect(atom.workspaceView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

      it "reuses the file when already open", ->
        atom.workspaceView.openSync('b')
        atom.workspaceView.openSingletonSync('b', split: 'right')
        expect(atom.workspaceView.panes.find('.pane').toArray()).toEqual [pane1[0]]

  describe ".open(filePath)", ->
    beforeEach ->
      spyOn(Pane.prototype, 'focus')

    describe "when there is no active pane", ->
      beforeEach ->
        atom.workspaceView.getActivePane().remove()
        expect(atom.workspaceView.getActivePane()).toBeUndefined()

      describe "when called with no path", ->
        it "creates a empty edit session as an item on a new pane, and focuses the pane", ->
          editor = null

          waitsForPromise ->
            atom.workspaceView.open().then (o) -> editor = o

          runs ->
            expect(atom.workspaceView.getActivePane().activeItem).toBe editor
            expect(editor.getPath()).toBeUndefined()
            expect(atom.workspaceView.getActivePane().focus).toHaveBeenCalled()

        it "can create multiple empty edit sessions as items on a pane", ->
          editor1 = null
          editor2 = null

          waitsForPromise ->
            atom.workspaceView.open()
              .then (o) ->
                editor1 = o
                atom.workspaceView.open()
              .then (o) ->
                editor2 = o

          runs ->
            expect(atom.workspaceView.getActivePane().getItems().length).toBe 2
            expect(editor1).not.toBe editor2

      describe "when called with a path", ->
        it "creates an edit session for the given path as an item on a new pane, and focuses the pane", ->
          editor = null
          waitsForPromise ->
            atom.workspaceView.open('b').then (o) -> editor = o

          runs ->
            expect(atom.workspaceView.getActivePane().activeItem).toBe editor
            expect(editor.getPath()).toBe require.resolve('./fixtures/dir/b')
            expect(atom.workspaceView.getActivePane().focus).toHaveBeenCalled()

    describe "when there is an active pane", ->
      [activePane] = []

      beforeEach ->
        activePane = atom.workspaceView.getActivePane()

      describe "when called with no path", ->
        it "opens an edit session with an empty buffer as an item in the active pane and focuses it", ->
          editor = null

          waitsForPromise ->
            atom.workspaceView.open().then (o) -> editor = o

          runs ->
            expect(activePane.getItems().length).toBe 2
            expect(activePane.activeItem).toBe editor
            expect(editor.getPath()).toBeUndefined()
            expect(activePane.focus).toHaveBeenCalled()

      describe "when called with a path", ->
        describe "when the active pane already has an item for the given path", ->
          it "shows the existing edit session in the pane", ->
            previousEditor = activePane.activeItem

            editor = null
            waitsForPromise ->
              atom.workspaceView.open('b').then (o) -> editor = o

            runs ->
              expect(activePane.activeItem).toBe editor
              expect(editor).not.toBe previousEditor

            waitsForPromise ->
              atom.workspaceView.open(previousEditor.getPath()).then (o) -> editor = o

            runs ->
              expect(editor).toBe previousEditor
              expect(activePane.activeItem).toBe editor
              expect(activePane.focus).toHaveBeenCalled()

        describe "when the active pane does not have an existing item for the given path", ->
          it "creates a new edit session for the given path in the active pane", ->
            editor = null

            waitsForPromise ->
              atom.workspaceView.open('b').then (o) -> editor = o

            runs ->
              expect(activePane.activeItem).toBe editor
              expect(activePane.getItems().length).toBe 2
              expect(activePane.focus).toHaveBeenCalled()

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

  describe ".eachBuffer(callback)", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "invokes the callback for existing buffer", ->
      count = 0
      count = 0
      callbackBuffer = null
      callback = (buffer) ->
        callbackBuffer = buffer
        count++
      atom.workspaceView.eachBuffer(callback)
      expect(count).toBe 1
      expect(callbackBuffer).toBe atom.workspaceView.getActiveView().getBuffer()

    it "invokes the callback for new buffer", ->
      count = 0
      callbackBuffer = null
      callback = (buffer) ->
        callbackBuffer = buffer
        count++

      atom.workspaceView.eachBuffer(callback)
      count = 0
      callbackBuffer = null
      atom.workspaceView.openSync(require.resolve('./fixtures/sample.txt'))
      expect(count).toBe 1
      expect(callbackBuffer).toBe atom.workspaceView.getActiveView().getBuffer()
