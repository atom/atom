$ = require 'jquery'
fs = require 'fs'
RootView = require 'root-view'
Buffer = require 'buffer'

describe "RootView", ->
  rootView = null
  project = null
  url = null

  beforeEach ->
    url = require.resolve 'fixtures/dir/a'
    rootView = new RootView({url})
    rootView.enableKeymap()
    project = rootView.project

  describe "initialize", ->
    describe "when called with a url that references a file", ->
      it "creates a project for the file's parent directory and opens it in the editor", ->
        expect(rootView.project.url).toBe fs.directory(url)
        expect(rootView.lastActiveEditor().buffer.path).toBe url

    describe "when called with a url that references a directory", ->
      it "creates a project for the directory and opens an empty buffer", ->
        url = require.resolve 'fixtures/dir/'
        rootView = new RootView({url})

        expect(rootView.project.url).toBe url
        expect(rootView.lastActiveEditor().buffer.url).toBeUndefined()

    describe "when not called with a url", ->
      it "opens an empty buffer", ->
        rootView = new RootView
        expect(rootView.lastActiveEditor().buffer.url).toBeUndefined()

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
          expect(rootView.find('.row .editor').length).toBe 2
          expect(rootView.find('.row .editor:eq(0)').view()).toBe editor1
          editor2 = rootView.find('.row .editor:eq(1)').view()
          expect(editor2.buffer).toBe editor1.buffer
          expect(editor2.getCursorScreenPosition()).toEqual [3, 2]

          expectedColumnWidth = Math.floor(rootView.width() / 2)
          expect(editor1.outerWidth()).toBe expectedColumnWidth
          expect(editor2.position().left).toBe expectedColumnWidth
          expect(editor2.outerWidth()).toBe expectedColumnWidth

          # expect(editor1.has(':focus')).not.toExist()
          # expect(editor2.has(':focus')).toExist()

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

          expectedColumnWidth = Math.floor(rootView.width() / 2)
          expect(editor2.outerWidth()).toBe expectedColumnWidth
          expect(editor1.position().left).toBe expectedColumnWidth
          expect(editor1.outerWidth()).toBe expectedColumnWidth

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

          expectedRowHeight = Math.floor(rootView.height() / 2)
          expect(editor2.outerHeight()).toBe expectedRowHeight
          expect(editor1.position().top).toBe expectedRowHeight
          expect(editor1.outerHeight()).toBe expectedRowHeight

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

          expectedRowHeight = Math.floor(rootView.height() / 2)
          expect(editor1.outerHeight()).toBe expectedRowHeight
          expect(editor2.position().top).toBe expectedRowHeight
          expect(editor2.outerHeight()).toBe expectedRowHeight

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
        editor1 = row1.children(':eq(1)')
        expect(column1.outerWidth()).toBe Math.floor(2/3 * rootView.width())
        expect(column1.outerHeight()).toBe rootView.height()
        expect(editor1.outerWidth()).toBe Math.floor(1/3 * rootView.width())
        expect(editor1.outerHeight()).toBe rootView.height()
        expect(editor1.position().left).toBe column1.outerWidth()

        expect(column1.children().length).toBe 2
        row2 = column1.children(':eq(0)')
        editor2 = column1.children(':eq(1)')
        expect(row2.outerWidth()).toBe column1.outerWidth()
        expect(row2.height()).toBe Math.floor(2/3 * rootView.height())
        expect(editor2.outerWidth()).toBe column1.outerWidth()
        expect(editor2.outerHeight()).toBe Math.floor(1/3 * rootView.height())
        expect(editor2.position().top).toBe row2.height()

        expect(row2.children().length).toBe 2
        column3 = row2.children(':eq(0)')
        editor3 = row2.children(':eq(1)')
        expect(column3.outerWidth()).toBe Math.floor(1/3 * rootView.width())
        expect(column3.outerHeight()).toBe row2.outerHeight()
        expect(editor3.outerWidth()).toBe Math.floor(1/3 * rootView.width())
        expect(editor3.height()).toBe row2.outerHeight()
        expect(editor3.position().left).toBe column3.width()

        expect(column3.children().length).toBe 2
        editor4 = column3.children(':eq(0)')
        editor5 = column3.children(':eq(1)')
        expect(editor4.outerWidth()).toBe column3.width()
        expect(editor4.outerHeight()).toBe Math.floor(1/3 * rootView.height())
        expect(editor5.outerWidth()).toBe column3.width()
        expect(editor5.position().top).toBe editor4.outerHeight()
        expect(editor5.outerHeight()).toBe Math.floor(1/3 * rootView.height())

    describe "when close is triggered on an editor pane", ->
      it "adjusts the layout, focuses the next most-recently active editor, and closes the window when there are no remaining editors", ->
        spyOn(window, 'close')
        editor = rootView.find('.editor').view()
        editor.trigger 'split-right'
        editor.trigger 'split-right'
        editor.trigger 'split-right'

        [editor1, editor2, editor3, editor4] = rootView.find('.editor').map -> $(this).view()

        editor2.focus()
        editor1.focus()
        editor3.focus()
        editor4.focus()

        editor4.trigger 'close'
        expect(editor3.isFocused).toBeTruthy()
        expect(editor1.outerWidth()).toBe Math.floor(rootView.width() / 3)
        expect(editor2.outerWidth()).toBe Math.floor(rootView.width() / 3)
        expect(editor3.outerWidth()).toBe Math.floor(rootView.width() / 3)

        editor3.trigger 'close'
        expect(editor1.isFocused).toBeTruthy()
        expect(editor1.outerWidth()).toBe Math.floor(rootView.width() / 2)
        expect(editor2.outerWidth()).toBe Math.floor(rootView.width() / 2)

        editor1.trigger 'close'
        expect(editor2.isFocused).toBeTruthy()
        expect(editor2.outerWidth()).toBe Math.floor(rootView.width())

        expect(window.close).not.toHaveBeenCalled()
        editor2.trigger 'close'
        expect(window.close).toHaveBeenCalled()

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

  describe ".addPane(view)", ->
    it "adds the given view to the rootView (at the bottom by default)", ->
      expect(rootView.children().length).toBe 1
      rootView.addPane $('<div id="foo">')
      expect(rootView.children().length).toBe 2

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
            expect(rootView.fileFinder.urlList.children('li').length).toBe paths.length

            for path in paths
              relativePath = path.replace(project.url, '')
              expect(rootView.fileFinder.urlList.find("li:contains(#{relativePath}):not(:contains(#{project.url}))")).toExist()

      describe "when there is no project", ->
        beforeEach ->
          rootView = new RootView

        it "does not open the FileFinder", ->
          expect(rootView.lastActiveEditor().buffer.url).toBeUndefined()
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

        expectedUrl = project.url + selectedLi.text()
        expect(editor1.buffer.url).not.toBe expectedUrl
        expect(editor2.buffer.url).not.toBe expectedUrl

        # debugger
        rootView.fileFinder.trigger 'file-finder:select-file'

        expect(editor1.buffer.url).not.toBe expectedUrl
        expect(editor2.buffer.url).toBe expectedUrl

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

