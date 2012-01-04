$ = require 'jquery'
fs = require 'fs'
RootView = require 'root-view'

describe "RootView", ->
  rootView = null
  url = null

  beforeEach ->
    url = require.resolve 'fixtures/dir/a'
    rootView = RootView.build {url}

  describe "initialize", ->
    describe "when called with a url that references a file", ->
      it "creates a project for the file's parent directory and opens it in the editor", ->
        expect(rootView.project.url).toBe fs.directory(url)
        expect(rootView.editor.buffer.url).toBe url

    describe "when called with a url that references a directory", ->
      it "creates a project for the directory and opens and empty buffer", ->
        url = require.resolve 'fixtures/dir'
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

  describe ".toggleFileFinder()", ->
    describe "when there is a project", ->
      it "shows the FileFinder when it is not on screen and hides it when it is", ->
        runs ->
          expect(rootView.find('.file-finder')).not.toExist()

        waitsForPromise ->
          rootView.toggleFileFinder()

        runs ->
          expect(rootView.find('.file-finder')).toExist()
          rootView.toggleFileFinder()
          expect(rootView.find('.file-finder')).not.toExist()

      it "shows all urls for the current project", ->
        waitsForPromise ->
          rootView.toggleFileFinder()
        runs ->
          expect(rootView.fileFinder.urlList.children('li').length).toBe 3

      it "removes common path prefix from files", ->
        waitsForPromise ->
          rootView.toggleFileFinder()

        runs ->
          commonPathPattern = new RegExp("^" + fs.directory(url))
          expect(rootView.fileFinder.urlList.children('li:first').text()).not.toMatch commonPathPattern

    describe "when there is no project", ->
      beforeEach ->
        rootView = RootView.build()

      it "does not open the FileFinder", ->
        expect(rootView.editor.buffer.url).toBeUndefined()
        expect(rootView.find('.file-finder')).not.toExist()
        rootView.toggleFileFinder()
        expect(rootView.find('.file-finder')).not.toExist()

