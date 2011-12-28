$ = require 'jquery'
Layout = require 'layout'

fdescribe "Layout", ->
  layout = null
  beforeEach -> layout = Layout.build()

  describe ".addPane(view)", ->
    it "adds the given view to the layout (at the bottom by default)", ->
      expect(layout.vertical.children().length).toBe 1

      layout.addPane $('<div id="foo">')

      expect(layout.vertical.children().length).toBe 2

