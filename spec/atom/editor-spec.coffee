Buffer = require 'buffer'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
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
    it "creates a pre element for each line in the buffer, with the html-escaped text of the line", ->
      expect(editor.lines.find('pre').length).toEqual(buffer.numLines())
      expect(buffer.getLine(2)).toContain('<')
      expect(editor.lines.find('pre:eq(2)').html()).toContain '&lt;'

    it "renders a non-breaking space for empty lines", ->
      expect(buffer.getLine(10)).toBe ''
      expect(editor.lines.find('pre:eq(10)').html()).toBe '&nbsp;'

    it "sets the cursor to the beginning of the file", ->
      expect(editor.getPosition()).toEqual(row: 0, column: 0)

  describe "cursor movement", ->
    describe ".setPosition({row, column})", ->
      it "moves the cursor to cover the character at the given row and column", ->
        editor.attachToDom()
        editor.setPosition(row: 2, column: 2)

        expect(editor.cursor.position().top).toBe(2 * editor.lineHeight)
        expect(editor.cursor.position().left).toBe(2 * editor.charWidth)

    describe "when the arrow keys are pressed", ->
      it "moves the cursor by a single row/column", ->
        editor.trigger keydownEvent('right')
        expect(editor.getPosition()).toEqual(row: 0, column: 1)

        editor.trigger keydownEvent('down')
        expect(editor.getPosition()).toEqual(row: 1, column: 1)

        editor.trigger keydownEvent('left')
        expect(editor.getPosition()).toEqual(row: 1, column: 0)

        editor.trigger keydownEvent('up')
        expect(editor.getPosition()).toEqual(row: 0, column: 0)

    describe "vertical movement", ->
      describe "auto-scrolling", ->
        beforeEach ->
          editor.attachToDom()
          editor.focus()
          editor.scrollMargin = 3

        it "scrolls the buffer with the specified scroll margin when cursor approaches the end of the screen", ->
          editor.height(editor.lineHeight * 10)

          _.times 6, -> editor.moveDown()
          expect(editor.scrollTop()).toBe(0)

          editor.moveDown()
          expect(editor.scrollTop()).toBe(editor.lineHeight)
          editor.moveDown()
          expect(editor.scrollTop()).toBe(editor.lineHeight * 2)

          _.times 3, -> editor.moveUp()
          expect(editor.scrollTop()).toBe(editor.lineHeight * 2)

          editor.moveUp()
          expect(editor.scrollTop()).toBe(editor.lineHeight)

          editor.moveUp()
          expect(editor.scrollTop()).toBe(0)

        it "reduces scroll margins when there isn't enough height to maintain them and scroll smoothly", ->
          editor.height(editor.lineHeight * 5)

          _.times 3, -> editor.moveDown()
          expect(editor.scrollTop()).toBe(editor.lineHeight)

          editor.moveUp()
          expect(editor.scrollTop()).toBe(0)

      describe "goal column retention", ->
        lineLengths = null

        beforeEach ->
          lineLengths = buffer.getLines().map (line) -> line.length
          expect(lineLengths[3]).toBeGreaterThan(lineLengths[4])
          expect(lineLengths[5]).toBeGreaterThan(lineLengths[4])
          expect(lineLengths[6]).toBeGreaterThan(lineLengths[3])

        it "retains the goal column when moving up", ->
          expect(lineLengths[6]).toBeGreaterThan(32)
          editor.setPosition(row: 6, column: 32)

          editor.moveUp()
          expect(editor.getPosition().column).toBe lineLengths[5]

          editor.moveUp()
          expect(editor.getPosition().column).toBe lineLengths[4]

          editor.moveUp()
          expect(editor.getPosition().column).toBe 32

        it "retains the goal column when moving down", ->
          editor.setPosition(row: 3, column: lineLengths[3])

          editor.moveDown()
          expect(editor.getPosition().column).toBe lineLengths[4]

          editor.moveDown()
          expect(editor.getPosition().column).toBe lineLengths[5]

          editor.moveDown()
          expect(editor.getPosition().column).toBe lineLengths[3]

        it "clears the goal column when the cursor is set", ->
          # set a goal column by moving down
          editor.setPosition(row: 3, column: lineLengths[3])
          editor.moveDown()
          expect(editor.getPosition().column).not.toBe 6

          # clear the goal column by explicitly setting the cursor position
          editor.setColumn(6)
          expect(editor.getPosition().column).toBe 6

          editor.moveDown()
          expect(editor.getPosition().column).toBe 6

      describe "when up is pressed on the first line", ->
        it "moves the cursor to the beginning of the line, but retains the goal column", ->
          editor.setPosition(row: 0, column: 4)
          editor.moveUp()
          expect(editor.getPosition()).toEqual(row: 0, column: 0)

          editor.moveDown()
          expect(editor.getPosition()).toEqual(row: 1, column: 4)

      describe "when down is pressed on the last line", ->
        it "moves the cursor to the end of line, but retains the goal column", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.getLine(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setPosition(row: lastLineIndex, column: 1)
          editor.moveDown()
          expect(editor.getPosition()).toEqual(row: lastLineIndex, column: lastLine.length)

          editor.moveUp()
          expect(editor.getPosition().column).toBe 1

        it "retains a goal column of 0", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.getLine(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setPosition(row: lastLineIndex, column: 0)
          editor.moveDown()
          editor.moveUp()
          expect(editor.getPosition().column).toBe 0

    describe "horizontal movement", ->
      describe "when left is pressed on the first column", ->
        describe "when there is a previous line", ->
          it "wraps to the end of the previous line", ->
            editor.setPosition(row: 1, column: 0)
            editor.moveLeft()
            expect(editor.getPosition()).toEqual(row: 0, column: buffer.getLine(0).length)

        describe "when the cursor is on the first line", ->
          it "remains in the same position (0,0)", ->
            editor.setPosition(row: 0, column: 0)
            editor.moveLeft()
            expect(editor.getPosition()).toEqual(row: 0, column: 0)

      describe "when right is pressed on the last column", ->
        describe "when there is a subsequent line", ->
          it "wraps to the beginning of the next line", ->
            editor.setPosition(row: 0, column: buffer.getLine(0).length)
            editor.moveRight()
            expect(editor.getPosition()).toEqual(row: 1, column: 0)

        describe "when the cursor is on the last line", ->
          it "remains in the same position", ->
            lastLineIndex = buffer.getLines().length - 1
            lastLine = buffer.getLine(lastLineIndex)
            expect(lastLine.length).toBeGreaterThan(0)

            lastPosition = { row: lastLineIndex, column: lastLine.length }
            editor.setPosition(lastPosition)
            editor.moveRight()

            expect(editor.getPosition()).toEqual(lastPosition)

  describe "when the editor is attached to the dom", ->
    it "updates the pixel position of the cursor", ->
      editor.setPosition(row: 2, column: 2)

      editor.attachToDom()

      expect(editor.cursor.position().top).toBe(2 * editor.lineHeight)
      expect(editor.cursor.position().left).toBe(2 * editor.charWidth)

    it "is focused", ->
      editor.attachToDom()
      expect(editor).toMatchSelector ":has(:focus)"

  describe "when the editor is focused", ->
    it "focuses the hidden input", ->
      editor.attachToDom()
      editor.focus()
      expect(editor).not.toMatchSelector ':focus'
      expect(editor.hiddenInput).toMatchSelector ':focus'

  describe "when text input events are triggered on the hidden input element", ->
    it "inserts the typed character at the cursor position, both in the buffer and the pre element", ->
      editor.setPosition(row: 1, column: 6)

      expect(editor.getCurrentLine().charAt(6)).not.toBe 'q'

      editor.hiddenInput.textInput 'q'

      expect(editor.getCurrentLine().charAt(6)).toBe 'q'
      expect(editor.getPosition()).toEqual(row: 1, column: 7)
      # expect(editor.lines.find('pre:eq(1)')).toHaveText editor.getCurrentLine()

  describe "when return is pressed", ->
    describe "when the cursor is at the beginning of a line", ->
      it "inserts an empty line before it", ->
        editor.setPosition(row: 1, column: 0)

        editor.trigger keydownEvent('enter')

        expect(editor.lines.find('pre:eq(1)')).toHaveHtml '&nbsp;'
        expect(editor.getPosition()).toEqual(row: 2, column: 0)

    describe "when the cursor is in the middle of a line", ->
      it "splits the current line to form a new line", ->
        editor.setPosition(row: 1, column: 6)

        originalLine = editor.lines.find('pre:eq(1)').text()
        lineBelowOriginalLine = editor.lines.find('pre:eq(2)').text()
        editor.trigger keydownEvent('enter')

        expect(editor.lines.find('pre:eq(1)')).toHaveText originalLine[0...6]
        expect(editor.lines.find('pre:eq(2)')).toHaveText originalLine[6..]
        expect(editor.lines.find('pre:eq(3)')).toHaveText lineBelowOriginalLine
        expect(editor.getPosition()).toEqual(row: 2, column: 0)

    describe "when the cursor is on the end of a line", ->
      it "inserts an empty line after it", ->
        editor.setPosition(row: 1, column: buffer.getLine(1).length)

        editor.trigger keydownEvent('enter')

        expect(editor.lines.find('pre:eq(2)')).toHaveHtml '&nbsp;'
        expect(editor.getPosition()).toEqual(row: 2, column: 0)

  describe "when backspace is pressed", ->
    describe "when the cursor is on the middle of the line", ->
      it "removes the character before the cursor", ->
        editor.setPosition(row: 1, column: 7)
        spyOn(buffer, 'backspace').andCallThrough()

        editor.trigger keydownEvent('backspace')

        expect(buffer.backspace).toHaveBeenCalledWith(row: 1, column: 7)
        expect(editor.lines.find('pre:eq(1)')).toHaveText buffer.getLine(1)
        expect(editor.getPosition()).toEqual {row: 1, column: 6}

