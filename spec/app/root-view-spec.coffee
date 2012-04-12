$ = require 'jquery'
fs = require 'fs'
RootView = require 'root-view'
Buffer = require 'buffer'
Editor = require 'editor'

describe "RootView", ->
  rootView = null
  project = null
  path = null

  beforeEach ->
    path = require.resolve 'fixtures/dir/a'
    rootView = new RootView(pathToOpen: path)
    rootView.enableKeymap()
    project = rootView.project

  describe "initialize(viewState)", ->
    describe "when called with a pathToOpen", ->
      describe "when pathToOpen references a file", ->
        it "creates a project for the file's parent directory and opens it in the editor", ->
          expect(rootView.project.path).toBe fs.directory(path)
          expect(rootView.editors().length).toBe 1
          expect(rootView.editors()[0]).toHaveClass 'active'
          expect(rootView.activeEditor().buffer.getPath()).toBe path

      describe "when pathToOpen references a directory", ->
        it "creates a project for the directory does not open an editor", ->
          path = require.resolve 'fixtures/dir/'
          rootView = new RootView(pathToOpen: path)

          expect(rootView.project.path).toBe path
          expect(rootView.editors().length).toBe 0

    describe "when called with view state data returned from a previous call to RootView.prototype.serialize", ->
      viewState = null

      describe "when the serialized RootView does not have a project, only an unsaved buffer", ->
        buffer = null

        beforeEach ->
          rootView = new RootView
          editor1 = rootView.activeEditor()
          buffer = editor1.buffer
          editor1.splitRight()
          viewState = rootView.serialize()

        it "constructs the view with the same panes", ->
          rootView = new RootView(viewState)
          expect(rootView.project).toBeUndefined()
          expect(rootView.editors().length).toBe 2

      describe "when the serialized RootView has a project", ->
        beforeEach ->
          editor1 = rootView.activeEditor()
          editor2 = editor1.splitRight()
          editor3 = editor2.splitRight()
          editor4 = editor2.splitDown()
          editor2.setBuffer(new Buffer(require.resolve 'fixtures/dir/b'))
          editor3.setBuffer(new Buffer(require.resolve 'fixtures/sample.js'))
          editor3.setCursorScreenPosition([2, 3])
          editor4.setBuffer(new Buffer(require.resolve 'fixtures/sample.txt'))
          editor4.setCursorScreenPosition([0, 2])
          rootView.attachToDom()
          editor2.focus()
          viewState = rootView.serialize()
          rootView.remove()

        it "constructs the view with the same project and panes", ->
          rootView = new RootView(viewState)
          rootView.attachToDom()

          expect(rootView.editors().length).toBe 4
          editor1 = rootView.panes.find('.row > .pane .editor:eq(0)').view()
          editor3 = rootView.panes.find('.row > .pane .editor:eq(1)').view()
          editor2 = rootView.panes.find('.row > .column > .pane .editor:eq(0)').view()
          editor4 = rootView.panes.find('.row > .column > .pane .editor:eq(1)').view()

          expect(editor1.buffer.path).toBe require.resolve('fixtures/dir/a')
          expect(editor2.buffer.path).toBe require.resolve('fixtures/dir/b')
          expect(editor3.buffer.path).toBe require.resolve('fixtures/sample.js')
          expect(editor3.getCursorScreenPosition()).toEqual [2, 3]
          expect(editor4.buffer.path).toBe require.resolve('fixtures/sample.txt')
          expect(editor4.getCursorScreenPosition()).toEqual [0, 2]

          # ensure adjustSplitPanes is called
          expect(editor1.width()).toBeGreaterThan 0
          expect(editor2.width()).toBeGreaterThan 0
          expect(editor3.width()).toBeGreaterThan 0
          expect(editor4.width()).toBeGreaterThan 0

          # ensure correct editor is focused again
          expect(editor2.isFocused).toBeTruthy()
          expect(editor1.isFocused).toBeFalsy()
          expect(editor3.isFocused).toBeFalsy()
          expect(editor4.isFocused).toBeFalsy()

    describe "when called with no state data", ->
      it "opens an empty buffer", ->
        rootView = new RootView
        expect(rootView.editors().length).toBe 1
        expect(rootView.activeEditor().buffer.path).toBeUndefined()

  describe "focus", ->
    it "can receive focus if there is no active editor, but otherwise hands off focus to the active editor", ->
      rootView = new RootView(pathToOpen: require.resolve 'fixtures')
      rootView.attachToDom()
      expect(rootView).toMatchSelector(':focus')

      rootView.activeEditor() # lazily create an editor
      expect(rootView).not.toMatchSelector(':focus')
      expect(rootView.activeEditor().isFocused).toBeTruthy()

      rootView.focus()
      expect(rootView).not.toMatchSelector(':focus')
      expect(rootView.activeEditor().isFocused).toBeTruthy()

  describe "split editor panes", ->
    editor1 = null

    beforeEach ->
      rootView.attachToDom()
      editor1 = rootView.find('.editor').view()
      editor1.setBuffer(new Buffer(require.resolve 'fixtures/sample.js'))
      editor1.setCursorScreenPosition([3, 2])
      rootView.width(800)
      rootView.height(600)

    describe "vertical splits", ->
      describe "when split-right is triggered on the editor", ->
        it "places a new editor to the right of the current editor in a .horizontal div, and focuses the new editor", ->
          expect(rootView.find('.row')).not.toExist()

          editor1.trigger 'split-right'

          expect(rootView.find('.row')).toExist()
          expect(rootView.find('.row .pane .editor').length).toBe 2
          expect(rootView.find('.row .editor:eq(0)').view()).toBe editor1

          editor2 = rootView.find('.row .editor:eq(1)').view()

          expect(editor2.buffer).toBe editor1.buffer
          expect(editor2.getCursorScreenPosition()).toEqual [3, 2]

          [pane1, pane2] = [editor1.parent(), editor2.parent()]
          expectedColumnWidth = Math.floor(rootView.width() / 2)
          expect(pane1.outerWidth()).toBe expectedColumnWidth
          expect(pane2.position().left).toBe expectedColumnWidth
          expect(pane2.outerWidth()).toBe expectedColumnWidth

          expect(editor1.has(':focus')).not.toExist()
          expect(editor2.has(':focus')).toExist()

          # insertion reflected in both buffers
          editor1.buffer.insert([0, 0], 'ABC')
          expect(editor1.lines.find('.line:first').text()).toContain 'ABC'
          expect(editor2.lines.find('.line:first').text()).toContain 'ABC'

      describe "when split-left is triggered on the editor", ->
        it "places a new editor to the left of the current editor in a .row div, and focuses the new editor", ->
          expect(rootView.find('.row')).not.toExist()

          editor1.trigger 'split-left'

          expect(rootView.find('.row')).toExist()
          expect(rootView.find('.row .editor').length).toBe 2
          expect(rootView.find('.row .editor:eq(1)').view()).toBe editor1
          editor2 = rootView.find('.row .editor:eq(0)').view()
          expect(editor2.buffer).toBe editor1.buffer
          expect(editor2.getCursorScreenPosition()).toEqual [3, 2]

          [pane1, pane2] = [editor1.parent(), editor2.parent()]
          expectedColumnWidth = Math.floor(rootView.width() / 2)
          expect(pane2.outerWidth()).toBe expectedColumnWidth
          expect(pane1.position().left).toBe expectedColumnWidth
          expect(pane1.outerWidth()).toBe expectedColumnWidth

          expect(editor1.has(':focus')).not.toExist()
          expect(editor2.has(':focus')).toExist()

          # insertion reflected in both buffers
          editor1.buffer.insert([0, 0], 'ABC')
          expect(editor1.lines.find('.line:first').text()).toContain 'ABC'
          expect(editor2.lines.find('.line:first').text()).toContain 'ABC'

    describe "horizontal splits", ->
      describe "when split-up is triggered on the editor", ->
        it "places a new editor below the current editor in a .vertical div, and focuses the new editor", ->
          expect(rootView.find('.vertical')).not.toExist()

          editor1.trigger 'split-up'

          expect(rootView.find('.column')).toExist()
          expect(rootView.find('.column .editor').length).toBe 2
          expect(rootView.find('.column .editor:eq(1)').view()).toBe editor1
          editor2 = rootView.find('.column .editor:eq(0)').view()
          expect(editor2.buffer).toBe editor1.buffer
          expect(editor2.getCursorScreenPosition()).toEqual [3, 2]

          [pane1, pane2] = [editor1.parent(), editor2.parent()]
          expectedRowHeight = Math.floor(rootView.height() / 2)
          expect(pane2.outerHeight()).toBe expectedRowHeight
          expect(pane1.position().top).toBe expectedRowHeight
          expect(pane1.outerHeight()).toBe expectedRowHeight

          expect(editor1.has(':focus')).not.toExist()
          expect(editor2.has(':focus')).toExist()

          # insertion reflected in both buffers
          editor1.buffer.insert([0, 0], 'ABC')
          expect(editor1.lines.find('.line:first').text()).toContain 'ABC'
          expect(editor2.lines.find('.line:first').text()).toContain 'ABC'

      describe "when split-down is triggered on the editor", ->
        it "places a new editor below the current editor in a .vertical div, and focuses the new editor", ->
          expect(rootView.find('.column')).not.toExist()

          editor1.trigger 'split-down'

          expect(rootView.find('.column')).toExist()
          expect(rootView.find('.column .editor').length).toBe 2
          expect(rootView.find('.column .editor:eq(0)').view()).toBe editor1
          editor2 = rootView.find('.column .editor:eq(1)').view()
          expect(editor2.buffer).toBe editor1.buffer
          expect(editor2.getCursorScreenPosition()).toEqual [3, 2]

          [pane1, pane2] = [editor1.parent(), editor2.parent()]
          expectedRowHeight = Math.floor(rootView.height() / 2)
          expect(pane1.outerHeight()).toBe expectedRowHeight
          expect(pane2.position().top).toBe expectedRowHeight
          expect(pane2.outerHeight()).toBe expectedRowHeight

          expect(editor1.has(':focus')).not.toExist()
          expect(editor2.has(':focus')).toExist()

          # insertion reflected in both buffers
          editor1.buffer.insert([0, 0], 'ABC')
          expect(editor1.lines.find('.line:first').text()).toContain 'ABC'
          expect(editor2.lines.find('.line:first').text()).toContain 'ABC'

    describe "layout of nested vertical and horizontal splits", ->
      it "lays out rows and columns with a consistent width", ->
        editor = rootView.find('.editor:has(:focus)').view()
        editor.trigger 'split-left'
        editor = rootView.find('.editor:has(:focus)').view()
        editor.trigger 'split-up'
        editor = rootView.find('.editor:has(:focus)').view()
        editor.trigger 'split-left'
        editor = rootView.find('.editor:has(:focus)').view()
        editor.trigger 'split-up'

        row1 = rootView.panes.children(':eq(0)')
        expect(row1.children().length).toBe 2
        column1 = row1.children(':eq(0)')
        pane1 = row1.children(':eq(1)')
        expect(column1.outerWidth()).toBe Math.floor(2/3 * rootView.width())
        expect(column1.outerHeight()).toBe rootView.height()
        expect(pane1.outerWidth()).toBe Math.floor(1/3 * rootView.width())
        expect(pane1.outerHeight()).toBe rootView.height()
        expect(pane1.position().left).toBe column1.outerWidth()

        expect(column1.children().length).toBe 2
        row2 = column1.children(':eq(0)')
        pane2 = column1.children(':eq(1)')
        expect(row2.outerWidth()).toBe column1.outerWidth()
        expect(row2.height()).toBe Math.floor(2/3 * rootView.height())
        expect(pane2.outerWidth()).toBe column1.outerWidth()
        expect(pane2.outerHeight()).toBe Math.floor(1/3 * rootView.height())
        expect(pane2.position().top).toBe row2.height()

        expect(row2.children().length).toBe 2
        column3 = row2.children(':eq(0)')
        pane3 = row2.children(':eq(1)')
        expect(column3.outerWidth()).toBe Math.floor(1/3 * rootView.width())
        expect(column3.outerHeight()).toBe row2.outerHeight()
        expect(pane3.outerWidth()).toBe Math.floor(1/3 * rootView.width())
        expect(pane3.height()).toBe row2.outerHeight()
        expect(pane3.position().left).toBe column3.width()

        expect(column3.children().length).toBe 2
        pane4 = column3.children(':eq(0)')
        pane5 = column3.children(':eq(1)')
        expect(pane4.outerWidth()).toBe column3.width()
        expect(pane4.outerHeight()).toBe Math.floor(1/3 * rootView.height())
        expect(pane5.outerWidth()).toBe column3.width()
        expect(pane5.position().top).toBe pane4.outerHeight()
        expect(pane5.outerHeight()).toBe Math.floor(1/3 * rootView.height())

    describe "when close is triggered on an editor pane", ->
      it "adjusts the layout, focuses the next most-recently active editor, and focuses the RootView when there are no remaining editors", ->
        spyOn(window, 'close')
        editor = rootView.find('.editor').view()
        editor.trigger 'split-right'
        editor.trigger 'split-right'
        editor.trigger 'split-right'

        [editor1, editor2, editor3, editor4] = rootView.find('.editor').map -> $(this).view()
        [pane1, pane2, pane3, pane4] = [editor1.parent(), editor2.parent(), editor3.parent(), editor4.parent()]

        editor4.focus()
        editor4.trigger 'close'
        expect(editor1.isFocused).toBeTruthy()
        expect(pane1.outerWidth()).toBe Math.floor(rootView.width() / 3)
        expect(pane2.outerWidth()).toBe Math.floor(rootView.width() / 3)
        expect(pane3.outerWidth()).toBe Math.floor(rootView.width() / 3)

        editor3.focus()
        editor3.trigger 'close'
        expect(editor1.isFocused).toBeTruthy()
        expect(pane1.outerWidth()).toBe Math.floor(rootView.width() / 2)
        expect(pane2.outerWidth()).toBe Math.floor(rootView.width() / 2)

        editor1.trigger 'close'
        expect(editor2.isFocused).toBeTruthy()
        expect(pane2.outerWidth()).toBe Math.floor(rootView.width())

        expect(window.close).not.toHaveBeenCalled()
        editor2.trigger 'close'

        expect(rootView).toMatchSelector(':focus')

      it "removes a containing row if it becomes empty", ->
        editor = rootView.find('.editor').view()
        editor.trigger 'split-up'
        editor.trigger 'split-left'

        rootView.find('.row .editor').trigger 'close'
        expect(rootView.find('.row')).not.toExist()
        expect(rootView.find('.column')).toExist()

      it "removes a containing column if it becomes empty", ->
        editor = rootView.find('.editor').view()
        editor.trigger 'split-left'
        editor.trigger 'split-up'

        rootView.find('.column .editor').trigger 'close'
        expect(rootView.find('.column')).not.toExist()
        expect(rootView.find('.row')).toExist()

        expect(rootView.find('.editor').outerWidth()).toBe rootView.width()

  describe "the file finder", ->
    describe "when the toggle-file-finder event is triggered", ->
      describe "when there is a project", ->
        it "shows the FileFinder when it is not on screen and hides it when it is", ->
          rootView.attachToDom()
          expect(rootView.find('.file-finder')).not.toExist()

          rootView.find('.editor').trigger 'split-right'
          [editor1, editor2] = rootView.find('.editor').map -> $(this).view()

          rootView.trigger 'toggle-file-finder'

          expect(rootView.find('.file-finder')).toExist()
          expect(rootView.find('.file-finder input:focus')).toExist()
          rootView.trigger 'toggle-file-finder'

          expect(editor1.isFocused).toBeFalsy()
          expect(editor2.isFocused).toBeTruthy()
          expect(rootView.find('.editor:has(:focus)')).toExist()
          expect(rootView.find('.file-finder')).not.toExist()

        it "shows all relative file paths for the current project", ->
          rootView.trigger 'toggle-file-finder'

          project.getFilePaths().done (paths) ->
            expect(rootView.fileFinder.pathList.children('li').length).toBe paths.length

            for path in paths
              relativePath = path.replace(project.path, '')
              expect(rootView.fileFinder.pathList.find("li:contains(#{relativePath}):not(:contains(#{project.path}))")).toExist()

      describe "when there is no project", ->
        beforeEach ->
          rootView = new RootView

        it "does not open the FileFinder", ->
          expect(rootView.activeEditor().buffer.path).toBeUndefined()
          expect(rootView.find('.file-finder')).not.toExist()
          rootView.trigger 'toggle-file-finder'
          expect(rootView.find('.file-finder')).not.toExist()

    describe "when a path is selected in the file finder", ->
      it "opens the file associated with that path in the editor", ->
        rootView.attachToDom()
        rootView.find('.editor').trigger 'split-right'
        [editor1, editor2] = rootView.find('.editor').map -> $(this).view()

        rootView.trigger 'toggle-file-finder'
        rootView.fileFinder.trigger 'move-down'
        selectedLi = rootView.fileFinder.find('li:eq(1)')

        expectedPath = project.path + selectedLi.text()
        expect(editor1.buffer.path).not.toBe expectedPath
        expect(editor2.buffer.path).not.toBe expectedPath

        # debugger
        rootView.fileFinder.trigger 'file-finder:select-file'

        expect(editor1.buffer.path).not.toBe expectedPath
        expect(editor2.buffer.path).toBe expectedPath

  describe "text search", ->
    describe "when find event is triggered", ->
      it "pre-populates command panel's editor with /", ->
        rootView.trigger "find-in-file"
        expect(rootView.commandPanel.parent).not.toBeEmpty()
        expect(rootView.commandPanel.editor.getText()).toBe "/"

  describe "keymap wiring", ->
    commandHandler = null
    beforeEach ->
      commandHandler = jasmine.createSpy('commandHandler')
      rootView.on('foo-command', commandHandler)

      window.keymap.bindKeys('*', 'x': 'foo-command')

    describe "when a keydown event is triggered on the RootView (not originating from Ace)", ->
      it "triggers matching keybindings for that event", ->
        event = keydownEvent 'x', target: rootView[0]

        rootView.trigger(event)
        expect(commandHandler).toHaveBeenCalled()

  describe "document.title", ->
    it "is set to activeEditor's buffer path", ->
      expect(document.title).toBe path

    it "only listens to focused editors path changes", ->
      editor1 = rootView.activeEditor()
      expect(document.title).toBe path

      editor2 = rootView.activeEditor().splitLeft()
      editor2.setBuffer(new Buffer("second.txt"))
      editor2.focus()
      expect(document.title).toBe "second.txt"

      editor1.buffer.setPath("should-not-be-title.txt")
      expect(document.title).toBe "second.txt"

    it "sets title to 'untitled' when buffer's path is null", ->
      editor = rootView.activeEditor()
      editor.setBuffer(new Buffer())
      expect(document.title).toBe "untitled"
