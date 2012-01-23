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

    it "creates a pre element for each line in the buffer, with the html-escaped text of the line", ->
      expect(editor.lines.find('pre').length).toEqual(buffer.numLines())
      expect(buffer.getLine(2)).toContain('<')
      expect(editor.lines.find('pre:eq(2)').html()).toContain '&lt;'

    it "renders a non-breaking space for empty lines", ->
      expect(buffer.getLine(10)).toBe ''
      expect(editor.lines.find('pre:eq(10)').html()).toBe '&nbsp;'

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

    describe "when up is pressed on the first line", ->
      it "moves the cursor to the beginning of the line", ->
        editor.setPosition(row: 0, col: 4)
        editor.moveUp()
        expect(editor.getPosition()).toEqual(row: 0, col: 0)

    describe "when down is pressed on the last line", ->
      it "moves the cursor to the end of line", ->
        lastLineIndex = buffer.getLines().length - 1
        lastLine = buffer.getLine(lastLineIndex)
        expect(lastLine.length).toBeGreaterThan(0)

        editor.setPosition(row: lastLineIndex, col: 0)
        editor.moveDown()
        expect(editor.getPosition()).toEqual(row: lastLineIndex, col: lastLine.length)

    describe "when left is pressed on the first column", ->
      describe "when there is a previous line", ->
        it "wraps to the end of the previous line", ->
          editor.setPosition(row: 1, col: 0)
          editor.moveLeft()
          expect(editor.getPosition()).toEqual(row: 0, col: buffer.getLine(0).length)

      describe "when the cursor is on the first line", ->
        it "remains in the same position (0,0)", ->
          editor.setPosition(row: 0, col: 0)
          editor.moveLeft()
          expect(editor.getPosition()).toEqual(row: 0, col: 0)

    describe "when right is pressed on the last column", ->
      describe "when there is a subsequent line", ->
        it "wraps to the beginning of the next line", ->
          editor.setPosition(row: 0, col: buffer.getLine(0).length)
          editor.moveRight()
          expect(editor.getPosition()).toEqual(row: 1, col: 0)

      fdescribe "when the cursor is on the last line", ->
        it "remains in the same position", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.getLine(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          lastPosition = { row: lastLineIndex, col: lastLine.length }
          editor.setPosition(lastPosition)
          editor.moveRight()

          expect(editor.getPosition()).toEqual(lastPosition)


  describe ".setPosition({row, col})", ->
    it "moves the cursor to cover the character at the given row and column", ->
      editor.attachToDom()
      editor.setPosition(row: 2, col: 2)

      expect(editor.cursor.position().top).toBe(2 * editor.lineHeight)
      expect(editor.cursor.position().left).toBe(2 * editor.charWidth)


  describe "when the editor is attached to the dom", ->
    it "updates the pixel position of the cursor", ->
      editor.setPosition(row: 2, col: 2)

      editor.attachToDom()

      expect(editor.cursor.position().top).toBe(2 * editor.lineHeight)
      expect(editor.cursor.position().left).toBe(2 * editor.charWidth)

