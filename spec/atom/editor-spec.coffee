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

    describe "vertical movement", ->
      describe "when up is pressed on the first line", ->
        it "moves the cursor to the beginning of the line, but retains the goal column", ->
          editor.setPosition(row: 0, col: 4)
          editor.moveUp()
          expect(editor.getPosition()).toEqual(row: 0, col: 0)

          editor.moveDown()
          expect(editor.getPosition()).toEqual(row: 1, col: 4)

      describe "when down is pressed on the last line", ->
        it "moves the cursor to the end of line, but retains the goal column", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.getLine(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setPosition(row: lastLineIndex, col: 1)
          editor.moveDown()
          expect(editor.getPosition()).toEqual(row: lastLineIndex, col: lastLine.length)

          editor.moveUp()
          expect(editor.getPosition().col).toBe 1

        fit "retains a goal column of 0", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.getLine(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setPosition(row: lastLineIndex, col: 0)
          editor.moveDown()
          editor.moveUp()
          expect(editor.getPosition().col).toBe 0

      describe "goal column retention", ->
        lineLengths = null

        beforeEach ->
          lineLengths = buffer.getLines().map (line) -> line.length
          expect(lineLengths[3]).toBeGreaterThan(lineLengths[4])
          expect(lineLengths[5]).toBeGreaterThan(lineLengths[4])
          expect(lineLengths[6]).toBeGreaterThan(lineLengths[3])

        it "retains the goal column when moving up", ->
          expect(lineLengths[6]).toBeGreaterThan(32)
          editor.setPosition(row: 6, col: 32)

          editor.moveUp()
          expect(editor.getPosition().col).toBe lineLengths[5]

          editor.moveUp()
          expect(editor.getPosition().col).toBe lineLengths[4]

          editor.moveUp()
          expect(editor.getPosition().col).toBe 32

        it "retains the goal column when moving down", ->
          editor.setPosition(row: 3, col: lineLengths[3])

          editor.moveDown()
          expect(editor.getPosition().col).toBe lineLengths[4]

          editor.moveDown()
          expect(editor.getPosition().col).toBe lineLengths[5]

          editor.moveDown()
          expect(editor.getPosition().col).toBe lineLengths[3]

        it "clears the goal column when the cursor is set", ->
          # set a goal column by moving down
          editor.setPosition(row: 3, col: lineLengths[3])
          editor.moveDown()
          expect(editor.getPosition().col).not.toBe 6

          # clear the goal column by explicitly setting the cursor position
          editor.setColumn(6)
          expect(editor.getPosition().col).toBe 6

          editor.moveDown()
          expect(editor.getPosition().col).toBe 6

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

      describe "when the cursor is on the last line", ->
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

