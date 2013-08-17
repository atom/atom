$ = require 'jquery'
fsUtils = require 'fs-utils'
path = require 'path'
Project = require 'project'
RootView = require 'root-view'
Buffer = require 'text-buffer'
Editor = require 'editor'
Pane = require 'pane'
{View, $$} = require 'space-pen'

describe "RootView", ->
  pathToOpen = null

  beforeEach ->
    project.setPath(project.resolve('dir'))
    pathToOpen = project.resolve('a')
    window.rootView = new RootView
    rootView.enableKeymap()
    rootView.open(pathToOpen)
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
        rootView.open()
        editor1 = rootView.getActiveView()
        buffer = editor1.getBuffer()
        editor1.splitRight()
        expect(rootView.getActiveView()).toBe rootView.getEditors()[1]

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
        pane2.showItem(project.open('b'))
        pane3.showItem(project.open('../sample.js'))
        pane3.activeItem.setCursorScreenPosition([2, 4])
        pane4.showItem(project.open('../sample.txt'))
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

    describe "when a keydown event is triggered on the RootView", ->
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
        rootView.open('b')

      describe "when there is an active pane item", ->
        it "sets the title to the pane item's title plus the project path", ->
          item = rootView.getActivePaneItem()
          expect(rootView.title).toBe "#{item.getTitle()} - #{project.getPath()}"

      describe "when the title of the active pane item changes", ->
        it "updates the window title based on the item's new title", ->
          editSession = rootView.getActivePaneItem()
          editSession.buffer.setPath('/tmp/hi')
          expect(rootView.title).toBe "#{editSession.getTitle()} - #{project.getPath()}"

      describe "when the active pane's item changes", ->
        it "updates the title to the new item's title plus the project path", ->
          rootView.getActivePane().showNextItem()
          item = rootView.getActivePaneItem()
          expect(rootView.title).toBe "#{item.getTitle()} - #{project.getPath()}"

      describe "when the last pane item is removed", ->
        it "update the title to contain the project's path", ->
          rootView.getActivePane().remove()
          expect(rootView.getActivePaneItem()).toBeUndefined()
          expect(rootView.title).toBe "atom - #{project.getPath()}"

      describe "when an inactive pane's item changes", ->
        it "does not update the title", ->
          pane = rootView.getActivePane()
          pane.splitRight()
          initialTitle = rootView.title
          pane.showNextItem()
          expect(rootView.title).toBe initialTitle

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

  describe ".open(path, options)", ->
    describe "when there is no active pane", ->
      beforeEach ->
        spyOn(Pane.prototype, 'focus')
        rootView.getActivePane().remove()
        expect(rootView.getActivePane()).toBeUndefined()

      describe "when called with no path", ->
        it "creates a empty edit session as an item on a new pane, and focuses the pane", ->
          editSession = rootView.open()
          expect(rootView.getActivePane().activeItem).toBe editSession
          expect(editSession.getPath()).toBeUndefined()
          expect(rootView.getActivePane().focus).toHaveBeenCalled()

      describe "when called with a path", ->
        it "creates an edit session for the given path as an item on a new pane, and focuses the pane", ->
          editSession = rootView.open('b')
          expect(rootView.getActivePane().activeItem).toBe editSession
          expect(editSession.getPath()).toBe fsUtils.resolveOnLoadPath('fixtures/dir/b')
          expect(rootView.getActivePane().focus).toHaveBeenCalled()

      describe "when the changeFocus option is false", ->
        it "does not focus the new pane", ->
          editSession = rootView.open('b', changeFocus: false)
          expect(rootView.getActivePane().focus).not.toHaveBeenCalled()

    describe "when there is an active pane", ->
      [activePane, initialItemCount] = []
      beforeEach ->
        activePane = rootView.getActivePane()
        spyOn(activePane, 'focus')
        initialItemCount = activePane.getItems().length

      describe "when called with no path", ->
        it "opens an edit session with an empty buffer as an item on the active pane and focuses it", ->
          editSession = rootView.open()
          expect(activePane.getItems().length).toBe initialItemCount + 1
          expect(activePane.activeItem).toBe editSession
          expect(editSession.getPath()).toBeUndefined()
          expect(activePane.focus).toHaveBeenCalled()

      describe "when called with a path", ->
        describe "when the active pane already has an edit session item for the path being opened", ->
          it "shows the existing edit session on the pane", ->
            previousEditSession = activePane.activeItem

            editSession = rootView.open('b')
            expect(activePane.activeItem).toBe editSession
            expect(editSession).not.toBe previousEditSession

            editSession = rootView.open(previousEditSession.getPath())
            expect(editSession).toBe previousEditSession
            expect(activePane.activeItem).toBe editSession

            expect(activePane.focus).toHaveBeenCalled()

        describe "when the active pane does not have an edit session item for the path being opened", ->
          it "creates a new edit session for the given path in the active editor", ->
            editSession = rootView.open('b')
            expect(activePane.items.length).toBe 2
            expect(activePane.activeItem).toBe editSession
            expect(activePane.focus).toHaveBeenCalled()

      describe "when the changeFocus option is false", ->
        it "does not focus the active pane", ->
          editSession = rootView.open('b', changeFocus: false)
          expect(activePane.focus).not.toHaveBeenCalled()

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
      rootView.open(require.resolve('fixtures/sample.txt'))
      expect(count).toBe 1
      expect(callbackBuffer).toBe rootView.getActiveView().getBuffer()

  describe "when a 'new-editor' event is triggered", ->
    it "opens a new untitled editor", ->
      itemCount = rootView.getActivePane().getItems().length
      rootView.trigger 'new-editor'
      expect(rootView.getActivePaneItem().getPath()).toBeUndefined()
      expect(rootView.getActivePaneItem().getBuffer().fileExists()).toBeFalsy()
      expect(rootView.getActivePane().getItems().length).toBe itemCount + 1
