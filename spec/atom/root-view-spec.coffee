$ = require 'jquery'
fs = require 'fs'
RootView = require 'root-view'

describe "RootView", ->
  rootView = null
  project = null
  url = null

  beforeEach ->
    url = require.resolve 'fixtures/dir/a'
    rootView = RootView.build {url}
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
        rootView = RootView.build {url}

        expect(rootView.project.url).toBe url
        expect(rootView.editor.buffer.url).toBeUndefined()

    describe "when not called with a url", ->
      it "opens an empty buffer", ->
        rootView = RootView.build()
        expect(rootView.editor.buffer.url).toBeUndefined()

  describe ".addPane(view)", ->
    it "adds the given view to the rootView (at the bottom by default)", ->
      expect(rootView.vertical.children().length).toBe 1
      rootView.addPane $('<div id="foo">')
      expect(rootView.vertical.children().length).toBe 2

  describe "the file finder", ->
    describe "when the toggle-file-finder event is triggered", ->
      describe "when there is a project", ->
        it "shows the FileFinder when it is not on screen and hides it when it is", ->
          runs ->
            $('#jasmine-content').append(rootView)

            expect(rootView.find('.file-finder')).not.toExist()

          waitsForPromise ->
            rootView.resultOfTrigger 'toggle-file-finder'

          runs ->
            expect(rootView.find('.file-finder')).toExist()
            expect(rootView.find('.file-finder input:focus')).toExist()
            rootView.trigger 'toggle-file-finder'
            expect(rootView.find('.editor:focus')).toExist()
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
          rootView = RootView.build()

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
      atom.globalKeymap.bindKeys('*', 'x': 'foo-command')

    describe "when a keydown event is triggered on the RootView (not originating from Ace)", ->
      it "triggers matching keybindings for that event", ->
        event = keydownEvent 'x', target: rootView[0]

        rootView.trigger(event)
        expect(commandHandler).toHaveBeenCalled()

