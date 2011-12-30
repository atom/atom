$ = require 'jquery'
fs = require 'fs'
RootView = require 'root-view'

describe "RootView", ->
  rootView = null
  beforeEach -> rootView = RootView.build()

  describe ".addPane(view)", ->
    it "adds the given view to the rootView (at the bottom by default)", ->
      expect(rootView.vertical.children().length).toBe 1
      rootView.addPane $('<div id="foo">')
      expect(rootView.vertical.children().length).toBe 2

  describe "toggleFileFinder", ->
    describe "when the editor has a url", ->
      baseUrl = require.resolve('fixtures/file-finder-dir/a')

      beforeEach ->
        rootView.editor.open baseUrl

      it "shows the FileFinder when it is not on screen and hides it when it is", ->
        expect(rootView.find('.file-finder')).not.toExist()
        rootView.toggleFileFinder()
        expect(rootView.find('.file-finder')).toExist()
        rootView.toggleFileFinder()
        expect(rootView.find('.file-finder')).not.toExist()

      it "shows urls for all files (not directories) by recursivley searching directory of editor.url", ->
        rootView.toggleFileFinder()
        expect(rootView.fileFinder.urlList.children('li').length).toBe 3

      it "remove common path prefix from files", ->
        rootView.toggleFileFinder()
        commonPathPattern = new RegExp("^" + fs.directory(baseUrl))
        expect(rootView.fileFinder.urlList.children('li:first').text()).not.toMatch commonPathPattern

    describe "when the editor has no url", ->
      it "does not open the FileFinder", ->
        expect(rootView.editor.buffer.url).toBeUndefined()
        expect(rootView.find('.file-finder')).not.toExist()
        rootView.toggleFileFinder()
        expect(rootView.find('.file-finder')).not.toExist()


