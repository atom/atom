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
        expect(rootView.editor.buffer.path).toBe url

    describe "when called with a url that references a directory", ->
      it "creates a project for the directory and opens an empty buffer", ->
        url = require.resolve 'fixtures/dir/'
        rootView = new RootView({url})

        expect(rootView.project.url).toBe url
        expect(rootView.editor.buffer.url).toBeUndefined()

    describe "when not called with a url", ->
      it "opens an empty buffer", ->
        rootView = new RootView
        expect(rootView.editor.buffer.url).toBeUndefined()

  describe "split editor panes", ->
    describe "when split-right is triggered on the editor", ->
      it "places the a new editor to the right of the current editor in a .horizontal div, and focuses the new editor", ->
        rootView.attachToDom()

        expect(rootView.find('.horizontal')).not.toExist()

        editor1 = rootView.find('.editor').view()
        editor1.setBuffer(new Buffer(require.resolve 'fixtures/sample.js'))
        editor1.setCursorScreenPosition([3, 2])
        editor1.trigger 'split-right'

        expect(rootView.find('.horizontal')).toExist()
        expect(rootView.find('.horizontal .editor').length).toBe 2
        expect(rootView.find('.horizontal .editor:eq(0)').view()).toBe editor1
        editor2 = rootView.find('.horizontal .editor:eq(1)').view()
        expect(editor2.buffer).toBe editor1.buffer
        expect(editor2.getCursorScreenPosition()).toEqual [3, 2]
        expect(editor1).toHaveClass 'split'
        expect(editor2).toHaveClass 'split'

        expect(editor1.has(':focus')).not.toExist()
        expect(editor2.has(':focus')).toExist()

        # insertion reflected in both buffers
        editor1.buffer.insert([0, 0], 'ABC')
        expect(editor1.lines.find('.line:first').text()).toContain 'ABC'
        expect(editor2.lines.find('.line:first').text()).toContain 'ABC'


  describe ".addPane(view)", ->
    it "adds the given view to the rootView (at the bottom by default)", ->
      expect(rootView.children().length).toBe 1
      rootView.addPane $('<div id="foo">')
      expect(rootView.children().length).toBe 2

  describe "the file finder", ->
    describe "when the toggle-file-finder event is triggered", ->
      describe "when there is a project", ->
        it "shows the FileFinder when it is not on screen and hides it when it is", ->
          runs ->
            rootView.attachToDom()
            expect(rootView.find('.file-finder')).not.toExist()

          waitsForPromise ->
            rootView.resultOfTrigger 'toggle-file-finder'

          runs ->
            expect(rootView.find('.file-finder')).toExist()
            expect(rootView.find('.file-finder input:focus')).toExist()
            rootView.trigger 'toggle-file-finder'
            expect(rootView.find('.editor:has(:focus)')).toExist()
            expect(rootView.find('.file-finder')).not.toExist()

        it "shows all relative file paths for the current project", ->
          waitsForPromise ->
            rootView.resultOfTrigger 'toggle-file-finder'

          waitsForPromise ->
            project.getFilePaths().done (paths) ->
              expect(rootView.fileFinder.urlList.children('li').length).toBe paths.length

              for path in paths
                relativePath = path.replace(project.url, '')
                expect(rootView.fileFinder.urlList.find("li:contains(#{relativePath}):not(:contains(#{project.url}))")).toExist()

      describe "when there is no project", ->
        beforeEach ->
          rootView = new RootView

        it "does not open the FileFinder", ->
          expect(rootView.editor.buffer.url).toBeUndefined()
          expect(rootView.find('.file-finder')).not.toExist()
          rootView.trigger 'toggle-file-finder'
          expect(rootView.find('.file-finder')).not.toExist()

    describe "when a path is selected in the file finder", ->
      it "opens the file associated with that path in the editor", ->
        waitsForPromise -> rootView.resultOfTrigger 'toggle-file-finder'
        runs ->
          firstLi = rootView.fileFinder.find('li:first')
          rootView.fileFinder.trigger 'select'
          expect(rootView.editor.buffer.url).toBe(project.url + firstLi.text())

  describe "global keymap wiring", ->
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

