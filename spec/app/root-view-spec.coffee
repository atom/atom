$ = require 'jquery'
fs = require 'fs'
Project = require 'project'
RootView = require 'root-view'
Buffer = require 'buffer'
Editor = require 'editor'
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

  xdescribe "@deserialize()", ->
    viewState = null

    describe "when the serialized RootView has an unsaved buffer", ->
      it "constructs the view with the same panes", ->
        rootView.open()
        editor1 = rootView.getActiveEditor()
        buffer = editor1.getBuffer()
        editor1.splitRight()

        viewState = rootView.serialize()
        rootView.deactivate()
        window.rootView = RootView.deserialize(viewState)

        rootView.focus()
        expect(rootView.getEditors().length).toBe 2
        expect(rootView.getActiveEditor().getText()).toBe buffer.getText()
        expect(rootView.getTitle()).toBe "untitled – #{project.getPath()}"

    describe "when the serialized RootView has a project", ->
      describe "when there are open editors", ->
        it "constructs the view with the same panes", ->
          editor1 = rootView.getActiveEditor()
          editor2 = editor1.splitRight()
          editor3 = editor2.splitRight()
          editor4 = editor2.splitDown()
          editor2.edit(project.buildEditSession('b'))
          editor3.edit(project.buildEditSession('../sample.js'))
          editor3.setCursorScreenPosition([2, 4])
          editor4.edit(project.buildEditSession('../sample.txt'))
          editor4.setCursorScreenPosition([0, 2])
          rootView.attachToDom()
          editor2.focus()

          viewState = rootView.serialize()
          rootView.deactivate()
          window.rootView = RootView.deserialize(viewState)
          rootView.attachToDom()

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

          expect(rootView.getTitle()).toBe "#{fs.base(editor2.getPath())} – #{project.getPath()}"

      describe "where there are no open editors", ->
        it "constructs the view with no open editors", ->
          rootView.getActiveEditor().remove()
          expect(rootView.getEditors().length).toBe 0

          viewState = rootView.serialize()
          rootView.deactivate()
          window.rootView = RootView.deserialize(viewState)

          rootView.attachToDom()
          expect(rootView.getEditors().length).toBe 0

    describe "when a pane's wrapped view cannot be deserialized", ->
      it "renders an empty pane", ->
        viewState =
          panesViewState:
            deserializer: "Pane",
            wrappedView:
              deserializer: "BogusView"

        rootView.deactivate()
        window.rootView = RootView.deserialize(viewState)
        expect(rootView.find('.pane').length).toBe 1
        expect(rootView.find('.pane').children().length).toBe 0

  describe "focus", ->
    describe "when there is an active editor", ->
      it "hands off focus to the active editor", ->
        rootView.attachToDom()

        rootView.open() # create an editor
        expect(rootView).not.toMatchSelector(':focus')
        expect(rootView.getActiveEditor().isFocused).toBeTruthy()

        rootView.focus()
        expect(rootView).not.toMatchSelector(':focus')
        expect(rootView.getActiveEditor().isFocused).toBeTruthy()

    describe "when there is no active editor", ->
      beforeEach ->
        rootView.getActiveEditor().remove()
        rootView.attachToDom()

      describe "when are visible focusable elements (with a -1 tabindex)", ->
        it "passes focus to the first focusable element", ->
          rootView.horizontal.append $$ ->
            @div "One", id: 'one', tabindex: -1
            @div "Two", id: 'two', tabindex: -1

          rootView.focus()
          expect(rootView).not.toMatchSelector(':focus')
          expect(rootView.find('#one')).toMatchSelector(':focus')
          expect(rootView.find('#two')).not.toMatchSelector(':focus')

      describe "when there are no visible focusable elements", ->
        it "surrenders focus to the body", ->
          expect(document.activeElement).toBe $('body')[0]


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

  describe "title", ->
    describe "when the project has no path", ->
      it "sets the title to 'untitled'", ->
        project.setPath(undefined)
        expect(rootView.title).toBe 'untitled'

    describe "when the project has a path", ->
      describe "when there is no active pane item", ->
        it "sets the title to the project's path", ->
          rootView.getActivePane().remove()
          expect(rootView.getActivePaneItem()).toBeUndefined()
          expect(rootView.title).toBe project.getPath()

      describe "when there is an active pane item", ->
        it "sets the title to the pane item's title plus the project path", ->
          item = rootView.getActivePaneItem()
          expect(rootView.title).toBe "#{item.getTitle()} - #{project.getPath()}"

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
        rootView.getActivePane().remove()
        expect(rootView.getActivePane()).toBeUndefined()

      describe "when called with no path", ->
        it "opens / returns an edit session for an empty buffer in a new editor", ->
          editSession = rootView.open()
          expect(rootView.getActivePane().currentItem).toBe editSession
          expect(editSession.getPath()).toBeUndefined()

      describe "when called with a path", ->
        it "opens a buffer with the given path in a new editor", ->
          editSession = rootView.open('b')
          expect(rootView.getActivePane().currentItem).toBe editSession
          expect(editSession.getPath()).toBe require.resolve('fixtures/dir/b')

    describe "when there is an active pane", ->
      [activePane, initialItemCount] = []
      beforeEach ->
        activePane = rootView.getActivePane()
        initialItemCount = activePane.getItems().length

      describe "when called with no path", ->
        it "opens an edit session with an empty buffer in the active pane", ->
          editSession = rootView.open()
          expect(activePane.getItems().length).toBe initialItemCount + 1
          expect(activePane.currentItem).toBe editSession
          expect(editSession.getPath()).toBeUndefined()

      describe "when called with a path", ->
        describe "when the active pane already has an edit session item for the path being opened", ->
          it "shows the existing edit session on the pane", ->
            previousEditSession = activePane.currentItem

            editSession = rootView.open('b')
            expect(activePane.currentItem).toBe editSession

            editSession = rootView.open('a')
            expect(editSession).not.toBe previousEditSession
            expect(activePane.currentItem).toBe editSession

        describe "when the active pane does not have an edit session item for the path being opened", ->
          it "creates a new edit session for the given path in the active editor", ->
            editSession = rootView.open('b')
            expect(activePane.items.length).toBe 2
            expect(activePane.currentItem).toBe editSession

  describe ".saveAll()", ->
    it "saves all open editors", ->
      project.setPath('/tmp')
      file1 = '/tmp/atom-temp1.txt'
      file2 = '/tmp/atom-temp2.txt'
      fs.write(file1, "file1")
      fs.write(file2, "file2")
      rootView.open(file1)

      editor1 = rootView.getActiveEditor()
      buffer1 = editor1.activeEditSession.buffer
      expect(buffer1.getText()).toBe("file1")
      expect(buffer1.isModified()).toBe(false)
      buffer1.setText('edited1')
      expect(buffer1.isModified()).toBe(true)

      editor2 = editor1.splitRight()
      editor2.edit(project.buildEditSession('atom-temp2.txt'))
      buffer2 = editor2.activeEditSession.buffer
      expect(buffer2.getText()).toBe("file2")
      expect(buffer2.isModified()).toBe(false)
      buffer2.setText('edited2')
      expect(buffer2.isModified()).toBe(true)

      rootView.saveAll()

      expect(buffer1.isModified()).toBe(false)
      expect(fs.read(buffer1.getPath())).toBe("edited1")
      expect(buffer2.isModified()).toBe(false)
      expect(fs.read(buffer2.getPath())).toBe("edited2")

  describe "window:toggle-invisibles event", ->
    it "shows/hides invisibles in all open and future editors", ->
      rootView.height(200)
      rootView.attachToDom()
      rightEditor = rootView.getActiveEditor()
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
      expect(callbackEditor).toBe rootView.getActiveEditor()

    it "invokes the callback for new editor", ->
      count = 0
      callbackEditor = null
      callback = (editor) ->
        callbackEditor = editor
        count++

      rootView.eachEditor(callback)
      count = 0
      callbackEditor = null
      rootView.getActiveEditor().splitRight()
      expect(count).toBe 1
      expect(callbackEditor).toBe rootView.getActiveEditor()

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
      expect(callbackBuffer).toBe rootView.getActiveEditor().getBuffer()

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
      expect(callbackBuffer).toBe rootView.getActiveEditor().getBuffer()
