Buffer = require 'buffer'
Editor = require 'editor'
$ = require 'jquery'
fs = require 'fs'

describe "Editor", ->
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

  describe ".setPosition({row, col})", ->
    it "moves the cursor to cover the character at the given row and column", ->
      editor.attachToDom()
      editor.setBuffer(buffer)
      editor.setPosition(row: 2, col: 2)

      expect(editor.cursor.position().top).toBe(2 * editor.lineHeight())
      expect(editor.cursor.position().left).toBe(2 * editor.charWidth())

