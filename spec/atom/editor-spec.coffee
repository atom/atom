Buffer = require 'buffer'
Editor = require 'editor'
$ = require 'jquery'
fs = require 'fs'

fdescribe "Editor", ->
  buffer = null
  editor = null

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    editor = Editor.build()

  describe ".setBuffer", ->
    it "creates a pre element for each line in the buffer", ->
      editor.setBuffer(buffer)
      expect(editor.lines.find('pre').length).toEqual(buffer.numLines())

    it "sets the cursor to the beginning of the file", ->
      expect(editor.getPosition()).toEqual(row: 0, col: 0)

