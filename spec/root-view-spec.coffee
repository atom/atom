{$, $$, fs, RootView, View} = require 'atom'
Q = require 'q'
path = require 'path'
temp = require 'temp'
Pane = require '../src/pane'

describe "RootView", ->
  pathToOpen = null

  beforeEach ->
    project.setPath(project.resolve('dir'))
    pathToOpen = project.resolve('a')
    window.rootView = new RootView
    rootView.enableKeymap()
    rootView.openSync(pathToOpen)
    rootView.focus()

  describe "@deserialize()", ->
    viewState = null

    refreshRootViewAndProject = ->
      rootViewState = rootView.serialize()
      projectState = project.serialize()
      rootView.remove()
      project.destroy()
      window.project = deserialize(projectState)
      window.rootView = deserialize(rootViewState)
      rootView.attachToDom()

    describe "when the serialized RootView has an unsaved buffer", ->
      it "constructs the view with the same panes", ->
        rootView.attachToDom()
        rootView.openSync()
        editor1 = rootView.getActiveView()
        buffer = editor1.getBuffer()
        editor1.splitRight()
        expect(rootView.getActiveView()).toBe rootView.getEditors()[2]

        refreshRootViewAndProject()

        expect(rootView.getEditors().length).toBe 2
        expect(rootView.getActiveView()).toBe rootView.getEditors()[1]
        expect(rootView.title).toBe "untitled - #{project.getPath()}"

    describe "when there are open editors", ->
      it "constructs the view with the same panes", ->
        rootView.attachToDom()
        pane1 = rootView.getActivePane()
        pane2 = pane1.splitRight()
        pane3 = pane2.splitRight()
        pane4 = pane2.splitDown()
        pane2.showItem(project.openSync('b'))
        pane3.showItem(project.openSync('../sample.js'))
        pane3.activeItem.setCursorScreenPosition([2, 4])
        pane4.showItem(project.openSync('../sample.txt'))
        pane4.activeItem.setCursorScreenPosition([0, 2])
        pane2.focus()

        refreshRootViewAndProject()

        expect(rootView.getEditors().length).toBe 4
        editor1 = rootView.panes.find('.row > .pane .editor:eq(0)').view()
        editor3 = rootView.panes.find('.row > .pane .editor:eq(1)').view()
        editor2 = rootView.panes.find('.row > .column > .pane .editor:eq(0)').view()
        editor4 = rootView.panes.find('.row > .column > .pane .editor:eq(1)').view()

        expect(editor1.getPath()).toBe project.resolve('a')
        expect(editor2.getPath()).toBe project.resolve('b')
        expect(editor3.getPath()).toBe project.resolve('../sample.js')
        expect(editor3.getCursorScreenPosition()).toEqual [2, 4]
        expect(editor4.getPath()).toBe project.resolve('../sample.txt')
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

        expect(rootView.title).toBe "#{path.basename(editor2.getPath())} - #{project.getPath()}"

    describe "where there are no open editors", ->
      it "constructs the view with no open editors", ->
        rootView.getActivePane().remove()
        expect(rootView.getEditors().length).toBe 0
        refreshRootViewAndProject()
        expect(rootView.getEditors().length).toBe 0

  describe "focus", ->
    beforeEach ->
      rootView.attachToDom()

    describe "when there is an active view", ->
      it "hands off focus to the active view", ->
        editor = rootView.getActiveView()
        editor.isFocused = false
        rootView.focus()
        expect(editor.isFocused).toBeTruthy()

    describe "when there is no active view", ->
      beforeEach ->
        rootView.getActivePane().remove()
        expect(rootView.getActiveView()).toBeUndefined()
        rootView.attachToDom()
        expect(document.activeElement).toBe document.body

      describe "when are visible focusable elements (with a -1 tabindex)", ->
        it "passes focus to the first focusable element", ->
          focusable1 = $$ -> @div "One", id: 'one', tabindex: -1
          focusable2 = $$ -> @div "Two", id: 'two', tabindex: -1
          rootView.horizontal.append(focusable1, focusable2)
          expect(document.activeElement).toBe document.body

          rootView.focus()
          expect(document.activeElement).toBe focusable1[0]

      describe "when there are no visible focusable elements", ->
        it "surrenders focus to the body", ->
          focusable = $$ -> @div "One", id: 'one', tabindex: -1
          rootView.horizontal.append(focusable)
          focusable.hide()
          expect(document.activeElement).toBe document.body

          rootView.focus()
          expect(document.activeElement).toBe document.body

  describe "keymap wiring", ->
    commandHandler = null
    beforeEach ->
      commandHandler = jasmine.createSpy('commandHandler')
      rootView.on('foo-command', commandHandler)

      window.keymap.bindKeys('*', 'x': 'foo-command')

    describe "when a keydown event is triggered in the RootView", ->
      it "triggers matching keybindings for that event", ->
        event = keydownEvent 'x', target: rootView[0]

        rootView.trigger(event)
        expect(commandHandler).toHaveBeenCalled()

  describe "window title", ->
    describe "when the project has no path", ->
      it "sets the title to 'untitled'", ->
        project.setPath(undefined)
        expect(rootView.title).toBe 'untitled'

    describe "when the project has a path", ->
      beforeEach ->
        rootView.openSync('b')

      describe "when there is an active pane item", ->
        it "sets the title to the pane item's title plus the project path", ->
          item = rootView.getActivePaneItem()
          expect(rootView.title).toBe "#{item.getTitle()} - #{project.getPath()}"

      describe "when the title of the active pane item changes", ->
        it "updates the window title based on the item's new title", ->
          editSession = rootView.getActivePaneItem()
          editSession.buffer.setPath(path.join(temp.dir, 'hi'))
          expect(rootView.title).toBe "#{editSession.getTitle()} - #{project.getPath()}"

      describe "when the active pane's item changes", ->
        it "updates the title to the new item's title plus the project path", ->
          rootView.getActivePane().showNextItem()
          item = rootView.getActivePaneItem()
          expect(rootView.title).toBe "#{item.getTitle()} - #{project.getPath()}"

      describe "when the last pane item is removed", ->
        it "updates the title to contain the project's path", ->
          rootView.getActivePane().remove()
          expect(rootView.getActivePaneItem()).toBeUndefined()
          expect(rootView.title).toBe project.getPath()

      describe "when an inactive pane's item changes", ->
        it "does not update the title", ->
          pane = rootView.getActivePane()
          pane.splitRight()
          initialTitle = rootView.title
          pane.showNextItem()
          expect(rootView.title).toBe initialTitle

    describe "when the root view is deserialized", ->
      it "updates the title to contain the project's path", ->
        rootView2 = atom.deserializers.deserialize(rootView.serialize())
        item = rootView.getActivePaneItem()
        expect(rootView2.title).toBe "#{item.getTitle()} - #{project.getPath()}"
        rootView2.remove()

  describe "font size adjustment", ->
    it "increases/decreases font size when increase/decrease-font-size events are triggered", ->
      fontSizeBefore = config.get('editor.fontSize')
      rootView.trigger 'window:increase-font-size'
      expect(config.get('editor.fontSize')).toBe fontSizeBefore + 1
      rootView.trigger 'window:increase-font-size'
      expect(config.get('editor.fontSize')).toBe fontSizeBefore + 2
      rootView.trigger 'window:decrease-font-size'
      expect(config.get('editor.fontSize')).toBe fontSizeBefore + 1
      rootView.trigger 'window:decrease-font-size'
      expect(config.get('editor.fontSize')).toBe fontSizeBefore

    it "does not allow the font size to be less than 1", ->
      config.set("editor.fontSize", 1)
      rootView.trigger 'window:decrease-font-size'
      expect(config.get('editor.fontSize')).toBe 1

  describe ".openSync(filePath, options)", ->
    describe "when there is no active pane", ->
      beforeEach ->
        spyOn(Pane.prototype, 'focus')
        rootView.getActivePane().remove()
        expect(rootView.getActivePane()).toBeUndefined()

      describe "when called with no path", ->
        it "creates a empty edit session as an item on a new pane, and focuses the pane", ->
          editSession = rootView.openSync()
          expect(rootView.getActivePane().activeItem).toBe editSession
          expect(editSession.getPath()).toBeUndefined()
          expect(rootView.getActivePane().focus).toHaveBeenCalled()

        it "can create multiple empty edit sessions as an item on a new pane", ->
          editSession = rootView.openSync()
          editSession2 = rootView.openSync()
          expect(rootView.getActivePane().getItems().length).toBe 2
          expect(editSession).not.toBe editSession2

      describe "when called with a path", ->
        it "creates an edit session for the given path as an item on a new pane, and focuses the pane", ->
          editSession = rootView.openSync('b')
          expect(rootView.getActivePane().activeItem).toBe editSession
          expect(editSession.getPath()).toBe require.resolve('./fixtures/dir/b')
          expect(rootView.getActivePane().focus).toHaveBeenCalled()

      describe "when the changeFocus option is false", ->
        it "does not focus the new pane", ->
          editSession = rootView.openSync('b', changeFocus: false)
          expect(rootView.getActivePane().focus).not.toHaveBeenCalled()

      describe "when the split option is 'right'", ->
        it "creates a new pane and opens the file in said pane", ->
          editSession = rootView.openSync('b', split: 'right')
          expect(rootView.getActivePane().activeItem).toBe editSession
          expect(editSession.getPath()).toBe require.resolve('./fixtures/dir/b')

    describe "when there is an active pane", ->
      [activePane, initialItemCount] = []
      beforeEach ->
        activePane = rootView.getActivePane()
        spyOn(activePane, 'focus')
        initialItemCount = activePane.getItems().length

      describe "when called with no path", ->
        it "opens an edit session with an empty buffer as an item in the active pane and focuses it", ->
          editSession = rootView.openSync()
          expect(activePane.getItems().length).toBe initialItemCount + 1
          expect(activePane.activeItem).toBe editSession
          expect(editSession.getPath()).toBeUndefined()
          expect(activePane.focus).toHaveBeenCalled()

      describe "when called with a path", ->
        describe "when the active pane already has an edit session item for the path being opened", ->
          it "shows the existing edit session in the pane", ->
            previousEditSession = activePane.activeItem

            editSession = rootView.openSync('b')
            expect(activePane.activeItem).toBe editSession
            expect(editSession).not.toBe previousEditSession

            editSession = rootView.openSync(previousEditSession.getPath())
            expect(editSession).toBe previousEditSession
            expect(activePane.activeItem).toBe editSession

            expect(activePane.focus).toHaveBeenCalled()

        describe "when the active pane does not have an edit session item for the path being opened", ->
          it "creates a new edit session for the given path in the active editor", ->
            editSession = rootView.openSync('b')
            expect(activePane.items.length).toBe 2
            expect(activePane.activeItem).toBe editSession
            expect(activePane.focus).toHaveBeenCalled()

      describe "when the changeFocus option is false", ->
        it "does not focus the active pane", ->
          editSession = rootView.openSync('b', changeFocus: false)
          expect(activePane.focus).not.toHaveBeenCalled()

      describe "when the split option is 'right'", ->
        it "creates a new pane and opens the file in said pane", ->
          pane1 = rootView.getActivePane()

          editSession = rootView.openSync('b', split: 'right')
          pane2 = rootView.getActivePane()
          expect(pane2[0]).not.toBe pane1[0]
          expect(editSession.getPath()).toBe require.resolve('./fixtures/dir/b')

          expect(rootView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

          editSession = rootView.openSync('file1', split: 'right')
          pane3 = rootView.getActivePane()
          expect(pane3[0]).toBe pane2[0]
          expect(editSession.getPath()).toBe require.resolve('./fixtures/dir/file1')

          expect(rootView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

  describe ".openSingletonSync(filePath, options)", ->
    describe "when there is an active pane", ->
      [pane1] = []
      beforeEach ->
        spyOn(Pane.prototype, 'focus').andCallFake -> @makeActive()
        pane1 = rootView.getActivePane()

      it "creates a new pane and reuses the file when already open", ->
        rootView.openSingletonSync('b', split: 'right')
        pane2 = rootView.getActivePane()
        expect(pane2[0]).not.toBe pane1[0]
        expect(pane1.itemForUri('b')).toBeFalsy()
        expect(pane2.itemForUri('b')).not.toBeFalsy()
        expect(rootView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

        pane1.focus()
        expect(rootView.getActivePane()[0]).toBe pane1[0]

        rootView.openSingletonSync('b', split: 'right')
        pane3 = rootView.getActivePane()
        expect(pane3[0]).toBe pane2[0]
        expect(pane1.itemForUri('b')).toBeFalsy()
        expect(pane2.itemForUri('b')).not.toBeFalsy()
        expect(rootView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

      it "handles split: left by opening to the left pane when necessary", ->
        rootView.openSingletonSync('b', split: 'right')
        pane2 = rootView.getActivePane()
        expect(pane2[0]).not.toBe pane1[0]

        rootView.openSingletonSync('file1', split: 'left')

        activePane = rootView.getActivePane()
        expect(activePane[0]).toBe pane1[0]

        expect(pane1.itemForUri('file1')).toBeTruthy()
        expect(pane2.itemForUri('file1')).toBeFalsy()
        expect(rootView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

        pane2.focus()
        expect(rootView.getActivePane()[0]).toBe pane2[0]

        rootView.openSingletonSync('file1', split: 'left')
        activePane = rootView.getActivePane()
        expect(activePane[0]).toBe pane1[0]
        expect(rootView.panes.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]

      it "reuses the file when already open", ->
        rootView.openSync('b')
        rootView.openSingletonSync('b', split: 'right')
        expect(rootView.panes.find('.pane').toArray()).toEqual [pane1[0]]

  describe ".open(filePath)", ->
    beforeEach ->
      spyOn(Pane.prototype, 'focus')

    describe "when there is no active pane", ->
      beforeEach ->
        rootView.getActivePane().remove()
        expect(rootView.getActivePane()).toBeUndefined()

      describe "when called with no path", ->
        it "creates a empty edit session as an item on a new pane, and focuses the pane", ->
          editSession = null

          waitsForPromise ->
            rootView.open().then (o) -> editSession = o

          runs ->
            expect(rootView.getActivePane().activeItem).toBe editSession
            expect(editSession.getPath()).toBeUndefined()
            expect(rootView.getActivePane().focus).toHaveBeenCalled()

        it "can create multiple empty edit sessions as items on a pane", ->
          editSession1 = null
          editSession2 = null

          waitsForPromise ->
            rootView.open()
              .then (o) ->
                editSession1 = o
                rootView.open()
              .then (o) ->
                editSession2 = o

          runs ->
            expect(rootView.getActivePane().getItems().length).toBe 2
            expect(editSession1).not.toBe editSession2

      describe "when called with a path", ->
        it "creates an edit session for the given path as an item on a new pane, and focuses the pane", ->
          editSession = null
          waitsForPromise ->
            rootView.open('b').then (o) -> editSession = o

          runs ->
            expect(rootView.getActivePane().activeItem).toBe editSession
            expect(editSession.getPath()).toBe require.resolve('./fixtures/dir/b')
            expect(rootView.getActivePane().focus).toHaveBeenCalled()

    describe "when there is an active pane", ->
      [activePane] = []

      beforeEach ->
        activePane = rootView.getActivePane()

      describe "when called with no path", ->
        it "opens an edit session with an empty buffer as an item in the active pane and focuses it", ->
          editSession = null

          waitsForPromise ->
            rootView.open().then (o) -> editSession = o

          runs ->
            expect(activePane.getItems().length).toBe 2
            expect(activePane.activeItem).toBe editSession
            expect(editSession.getPath()).toBeUndefined()
            expect(activePane.focus).toHaveBeenCalled()

      describe "when called with a path", ->
        describe "when the active pane already has an item for the given path", ->
          it "shows the existing edit session in the pane", ->
            previousEditSession = activePane.activeItem

            editSession = null
            waitsForPromise ->
              rootView.open('b').then (o) -> editSession = o

            runs ->
              expect(activePane.activeItem).toBe editSession
              expect(editSession).not.toBe previousEditSession

            waitsForPromise ->
              rootView.open(previousEditSession.getPath()).then (o) -> editSession = o

            runs ->
              expect(editSession).toBe previousEditSession
              expect(activePane.activeItem).toBe editSession
              expect(activePane.focus).toHaveBeenCalled()

        describe "when the active pane does not have an existing item for the given path", ->
          it "creates a new edit session for the given path in the active pane", ->
            editSession = null

            waitsForPromise ->
              rootView.open('b').then (o) -> editSession = o

            runs ->
              expect(activePane.activeItem).toBe editSession
              expect(activePane.getItems().length).toBe 2
              expect(activePane.focus).toHaveBeenCalled()

  describe "window:toggle-invisibles event", ->
    it "shows/hides invisibles in all open and future editors", ->
      rootView.height(200)
      rootView.attachToDom()
      rightEditor = rootView.getActiveView()
      rightEditor.setText(" \t ")
      leftEditor = rightEditor.splitLeft()
      expect(rightEditor.find(".line:first").text()).toBe "    "
      expect(leftEditor.find(".line:first").text()).toBe "    "

      withInvisiblesShowing = "#{rightEditor.invisibles.space}#{rightEditor.invisibles.tab} #{rightEditor.invisibles.space}#{rightEditor.invisibles.eol}"

      rootView.trigger "window:toggle-invisibles"
      expect(rightEditor.find(".line:first").text()).toBe withInvisiblesShowing
      expect(leftEditor.find(".line:first").text()).toBe withInvisiblesShowing

      lowerLeftEditor = leftEditor.splitDown()
      expect(lowerLeftEditor.find(".line:first").text()).toBe withInvisiblesShowing

      rootView.trigger "window:toggle-invisibles"
      expect(rightEditor.find(".line:first").text()).toBe "    "
      expect(leftEditor.find(".line:first").text()).toBe "    "

      lowerRightEditor = rightEditor.splitDown()
      expect(lowerRightEditor.find(".line:first").text()).toBe "    "

  describe ".eachEditor(callback)", ->
    beforeEach ->
      rootView.attachToDom()

    it "invokes the callback for existing editor", ->
      count = 0
      callbackEditor = null
      callback = (editor) ->
        callbackEditor = editor
        count++
      rootView.eachEditor(callback)
      expect(count).toBe 1
      expect(callbackEditor).toBe rootView.getActiveView()

    it "invokes the callback for new editor", ->
      count = 0
      callbackEditor = null
      callback = (editor) ->
        callbackEditor = editor
        count++

      rootView.eachEditor(callback)
      count = 0
      callbackEditor = null
      rootView.getActiveView().splitRight()
      expect(count).toBe 1
      expect(callbackEditor).toBe rootView.getActiveView()

    it "returns a subscription that can be disabled", ->
      count = 0
      callback = (editor) -> count++

      subscription = rootView.eachEditor(callback)
      expect(count).toBe 1
      rootView.getActiveView().splitRight()
      expect(count).toBe 2
      subscription.off()
      rootView.getActiveView().splitRight()
      expect(count).toBe 2

  describe ".eachBuffer(callback)", ->
    beforeEach ->
      rootView.attachToDom()

    it "invokes the callback for existing buffer", ->
      count = 0
      count = 0
      callbackBuffer = null
      callback = (buffer) ->
        callbackBuffer = buffer
        count++
      rootView.eachBuffer(callback)
      expect(count).toBe 1
      expect(callbackBuffer).toBe rootView.getActiveView().getBuffer()

    it "invokes the callback for new buffer", ->
      count = 0
      callbackBuffer = null
      callback = (buffer) ->
        callbackBuffer = buffer
        count++

      rootView.eachBuffer(callback)
      count = 0
      callbackBuffer = null
      rootView.openSync(require.resolve('./fixtures/sample.txt'))
      expect(count).toBe 1
      expect(callbackBuffer).toBe rootView.getActiveView().getBuffer()
