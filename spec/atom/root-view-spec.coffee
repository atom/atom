$ = require 'jquery'
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
    it "shows the FileFinder when it is not on screen and hides it when it is", ->
      expect(rootView.find('.file-finder')).not.toExist()
      rootView.toggleFileFinder()
      expect(rootView.find('.file-finder')).toExist()
      rootView.toggleFileFinder()
      expect(rootView.find('.file-finder')).not.toExist()

