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
    editor.enableKeymap()
    editor.setBuffer(buffer)

  describe ".setBuffer", ->
    beforeEach ->

    it "creates a pre element for each line in the buffer", ->
      expect(editor.lines.find('pre').length).toEqual(buffer.numLines())

    it "sets the cursor to the beginning of the file", ->
      expect(editor.getPosition()).toEqual(row: 0, col: 0)

  describe "cursor movement", ->
    it "moves the cursor when arrow keys are pressed", ->
      editor.trigger keydownEvent('right')
      expect(editor.getPosition()).toEqual(row: 0, col: 1)

      editor.trigger keydownEvent('down')
      expect(editor.getPosition()).toEqual(row: 1, col: 1)

      editor.trigger keydownEvent('left')
      expect(editor.getPosition()).toEqual(row: 1, col: 0)

      editor.trigger keydownEvent('up')
      expect(editor.getPosition()).toEqual(row: 0, col: 0)


  describe ".setPosition({row, col})", ->
    it "moves the cursor to cover the character at the given row and column", ->
      editor.attachToDom()
      editor.setPosition(row: 2, col: 2)

      expect(editor.cursor.position().top).toBe(2 * editor.lineHeight())
      expect(editor.cursor.position().left).toBe(2 * editor.charWidth())


  describe "when the editor is attached to the dom", ->
    it "updates the pixel position of the cursor", ->
      editor.setPosition(row: 2, col: 2)

      editor.attachToDom()

      expect(editor.cursor.position().top).toBe(2 * editor.lineHeight())
      expect(editor.cursor.position().left).toBe(2 * editor.charWidth())

