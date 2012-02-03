Buffer = require 'buffer'
Editor = require 'editor'
Range = require 'range'
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

  describe "text rendering", ->
    it "creates a pre element for each line in the buffer with the html-escaped text of the line", ->
      expect(editor.lines.find('pre').length).toEqual(buffer.numLines())
      expect(buffer.getLine(2)).toContain('<')
      expect(editor.lines.find('pre:eq(2)').html()).toContain '&lt;'

      # renders empty lines with a non breaking space
      expect(buffer.getLine(10)).toBe ''
      expect(editor.lines.find('pre:eq(10)').html()).toBe '&nbsp;'

    it "syntax highlights code based on the file type", ->
      line1 = editor.lines.find('.line:first')
      expect(line1.find('span:eq(0)')).toMatchSelector '.keyword.definition'
      expect(line1.find('span:eq(0)').text()).toBe 'var'
      expect(line1.find('span:eq(1)')).toMatchSelector '.text'
      expect(line1.find('span:eq(1)').text()).toBe ' '
      expect(line1.find('span:eq(2)')).toMatchSelector '.identifier'
      expect(line1.find('span:eq(2)').text()).toBe 'quicksort'
      expect(line1.find('span:eq(4)')).toMatchSelector '.operator'
      expect(line1.find('span:eq(4)').text()).toBe '='

      line12 = editor.lines.find('.line:eq(11)')
      expect(line12.find('span:eq(1)')).toMatchSelector '.keyword'

    describe "when lines are updated in the buffer", ->
      it "syntax highlights the updated lines", ->
        expect(editor.lines.find('.line:eq(0) span:eq(0)')).toMatchSelector '.keyword.definition'
        buffer.insert([0, 4], "g")
        expect(editor.lines.find('.line:eq(0) span:eq(0)')).toMatchSelector '.keyword.definition'

  describe "cursor movement", ->
    describe ".setCursorPosition({row, column})", ->
      beforeEach ->
        editor.attachToDom()
        editor.setCursorPosition(row: 2, column: 2)

      it "moves the cursor to cover the character at the given row and column", ->
        expect(editor.getCursor().position().top).toBe(2 * editor.lineHeight)
        expect(editor.getCursor().position().left).toBe(2 * editor.charWidth)

      it "moves the hidden input element to the position of the cursor to prevent scrolling misbehavior", ->
        expect(editor.hiddenInput.position().top).toBe(2 * editor.lineHeight)
        expect(editor.hiddenInput.position().left).toBe(2 * editor.charWidth)

    describe "when the arrow keys are pressed", ->
      it "moves the cursor by a single row/column", ->
        editor.trigger keydownEvent('right')
        expect(editor.getCursorPosition()).toEqual(row: 0, column: 1)

        editor.trigger keydownEvent('down')
        expect(editor.getCursorPosition()).toEqual(row: 1, column: 1)

        editor.trigger keydownEvent('left')
        expect(editor.getCursorPosition()).toEqual(row: 1, column: 0)

        editor.trigger keydownEvent('up')
        expect(editor.getCursorPosition()).toEqual(row: 0, column: 0)

    describe "vertical movement", ->
      describe "auto-scrolling", ->
        beforeEach ->
          editor.attachToDom()
          editor.focus()
          editor.vScrollMargin = 3

        it "scrolls the buffer with the specified scroll margin when cursor approaches the end of the screen", ->
          editor.height(editor.lineHeight * 10)

          _.times 6, -> editor.moveCursorDown()
          expect(editor.scrollTop()).toBe(0)

          editor.moveCursorDown()
          expect(editor.scrollTop()).toBe(editor.lineHeight)
          editor.moveCursorDown()
          expect(editor.scrollTop()).toBe(editor.lineHeight * 2)

          _.times 3, -> editor.moveCursorUp()
          expect(editor.scrollTop()).toBe(editor.lineHeight * 2)

          editor.moveCursorUp()
          expect(editor.scrollTop()).toBe(editor.lineHeight)

          editor.moveCursorUp()
          expect(editor.scrollTop()).toBe(0)

        it "reduces scroll margins when there isn't enough height to maintain them and scroll smoothly", ->
          editor.height(editor.lineHeight * 5)

          _.times 3, -> editor.moveCursorDown()
          expect(editor.scrollTop()).toBe(editor.lineHeight)

          editor.moveCursorUp()
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
          editor.setCursorPosition(row: 6, column: 32)

          editor.moveCursorUp()
          expect(editor.getCursorPosition().column).toBe lineLengths[5]

          editor.moveCursorUp()
          expect(editor.getCursorPosition().column).toBe lineLengths[4]

          editor.moveCursorUp()
          expect(editor.getCursorPosition().column).toBe 32

        it "retains the goal column when moving down", ->
          editor.setCursorPosition(row: 3, column: lineLengths[3])

          editor.moveCursorDown()
          expect(editor.getCursorPosition().column).toBe lineLengths[4]

          editor.moveCursorDown()
          expect(editor.getCursorPosition().column).toBe lineLengths[5]

          editor.moveCursorDown()
          expect(editor.getCursorPosition().column).toBe lineLengths[3]

        it "clears the goal column when the cursor is set", ->
          # set a goal column by moving down
          editor.setCursorPosition(row: 3, column: lineLengths[3])
          editor.moveCursorDown()
          expect(editor.getCursorPosition().column).not.toBe 6

          # clear the goal column by explicitly setting the cursor position
          editor.setCursorColumn(6)
          expect(editor.getCursorPosition().column).toBe 6

          editor.moveCursorDown()
          expect(editor.getCursorPosition().column).toBe 6

      describe "when up is pressed on the first line", ->
        it "moves the cursor to the beginning of the line, but retains the goal column", ->
          editor.setCursorPosition(row: 0, column: 4)
          editor.moveCursorUp()
          expect(editor.getCursorPosition()).toEqual(row: 0, column: 0)

          editor.moveCursorDown()
          expect(editor.getCursorPosition()).toEqual(row: 1, column: 4)

      describe "when down is pressed on the last line", ->
        it "moves the cursor to the end of line, but retains the goal column", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.getLine(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setCursorPosition(row: lastLineIndex, column: 1)
          editor.moveCursorDown()
          expect(editor.getCursorPosition()).toEqual(row: lastLineIndex, column: lastLine.length)

          editor.moveCursorUp()
          expect(editor.getCursorPosition().column).toBe 1

        it "retains a goal column of 0", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.getLine(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setCursorPosition(row: lastLineIndex, column: 0)
          editor.moveCursorDown()
          editor.moveCursorUp()
          expect(editor.getCursorPosition().column).toBe 0

    describe "horizontal movement", ->
      describe "auto-scrolling", ->
        charWidth = null
        beforeEach ->
          editor.attachToDom()
          {charWidth} = editor
          editor.hScrollMargin = 5

        it "scrolls horizontally to keep the cursor on screen", ->
          editor.width(charWidth * 30)

          # moving right
          editor.setCursorPosition([2, 24])
          expect(editor.scrollLeft()).toBe 0

          editor.setCursorPosition([2, 25])
          expect(editor.scrollLeft()).toBe charWidth

          editor.setCursorPosition([2, 28])
          expect(editor.scrollLeft()).toBe charWidth * 4

          # moving left
          editor.setCursorPosition([2, 9])
          expect(editor.scrollLeft()).toBe charWidth * 4

          editor.setCursorPosition([2, 8])
          expect(editor.scrollLeft()).toBe charWidth * 3

          editor.setCursorPosition([2, 5])
          expect(editor.scrollLeft()).toBe 0

        it "reduces scroll margins when there isn't enough width to maintain them and scroll smoothly", ->
          editor.hScrollMargin = 6
          editor.width(charWidth * 7)

          editor.setCursorPosition([2, 3])
          expect(editor.scrollLeft()).toBe(0)

          editor.setCursorPosition([2, 4])
          expect(editor.scrollLeft()).toBe(charWidth)

          editor.setCursorPosition([2, 3])
          expect(editor.scrollLeft()).toBe(0)

      describe "when left is pressed on the first column", ->
        describe "when there is a previous line", ->
          it "wraps to the end of the previous line", ->
            editor.setCursorPosition(row: 1, column: 0)
            editor.moveCursorLeft()
            expect(editor.getCursorPosition()).toEqual(row: 0, column: buffer.getLine(0).length)

        describe "when the cursor is on the first line", ->
          it "remains in the same position (0,0)", ->
            editor.setCursorPosition(row: 0, column: 0)
            editor.moveCursorLeft()
            expect(editor.getCursorPosition()).toEqual(row: 0, column: 0)

      describe "when right is pressed on the last column", ->
        describe "when there is a subsequent line", ->
          it "wraps to the beginning of the next line", ->
            editor.setCursorPosition(row: 0, column: buffer.getLine(0).length)
            editor.moveCursorRight()
            expect(editor.getCursorPosition()).toEqual(row: 1, column: 0)

        describe "when the cursor is on the last line", ->
          it "remains in the same position", ->
            lastLineIndex = buffer.getLines().length - 1
            lastLine = buffer.getLine(lastLineIndex)
            expect(lastLine.length).toBeGreaterThan(0)

            lastPosition = { row: lastLineIndex, column: lastLine.length }
            editor.setCursorPosition(lastPosition)
            editor.moveCursorRight()

            expect(editor.getCursorPosition()).toEqual(lastPosition)

    describe "when a mousedown event occurs in the editor", ->
      it "re-positions the cursor to the clicked row / column", ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)
        pageX = editor.offset().left + 10 * editor.charWidth + 3
        pageY = editor.offset().top + 4 * editor.lineHeight - 2

        expect(editor.getCursorPosition()).toEqual(row: 0, column: 0)

        editor.lines.trigger mousedownEvent({pageX, pageY})

        expect(editor.getCursorPosition()).toEqual(row: 3, column: 10)

  describe "selection", ->
    selection = null

    beforeEach ->
      selection = editor.selection

    describe "when the arrow keys are pressed with the shift modifier", ->
      it "expands the selection up to the cursor's new location", ->
        editor.setCursorPosition(row: 1, column: 6)

        expect(selection.isEmpty()).toBeTruthy()

        editor.trigger keydownEvent('right', shiftKey: true)

        expect(selection.isEmpty()).toBeFalsy()
        range = selection.getRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 1, column: 7)

        editor.trigger keydownEvent('right', shiftKey: true)
        range = selection.getRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 1, column: 8)

        editor.trigger keydownEvent('down', shiftKey: true)
        range = selection.getRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 2, column: 8)

        editor.trigger keydownEvent('left', shiftKey: true)
        range = selection.getRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 2, column: 7)

        editor.trigger keydownEvent('up', shiftKey: true)
        range = selection.getRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 1, column: 7)

    describe "when the arrow keys are pressed without the shift modifier", ->
      makeNonEmpty = ->
        selection.setRange(new Range({row: 1, column: 2}, {row: 1, column: 5}))
        expect(selection.isEmpty()).toBeFalsy()

      it "clears the selection", ->
        makeNonEmpty()
        editor.trigger keydownEvent('right')
        expect(selection.isEmpty()).toBeTruthy()

        makeNonEmpty()
        editor.trigger keydownEvent('left')
        expect(selection.isEmpty()).toBeTruthy()

        makeNonEmpty()
        editor.trigger keydownEvent('up')
        expect(selection.isEmpty()).toBeTruthy()

        makeNonEmpty()
        editor.trigger keydownEvent('down')
        expect(selection.isEmpty()).toBeTruthy()

    describe "when the mouse is dragged across the text", ->
      it "creates a selection from the initial click to mouse cursor's location ", ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

        # start
        pageX = editor.offset().left + 10 * editor.charWidth + 3
        pageY = editor.offset().top + 4 * editor.lineHeight + 3
        editor.lines.trigger mousedownEvent({pageX, pageY})

        # moving changes selection
        pageX = editor.offset().left + 27 * editor.charWidth + 3
        pageY = editor.offset().top + 5 * editor.lineHeight + 3
        editor.lines.trigger mousemoveEvent({pageX, pageY})

        range = editor.selection.getRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        pageX = editor.offset().left + 3 * editor.charWidth + 3
        pageY = editor.offset().top + 8 * editor.lineHeight + 3
        editor.lines.trigger mousemoveEvent({pageX, pageY})

        range = editor.selection.getRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorPosition()).toEqual(row: 5, column: 27)

  describe "buffer manipulation", ->
    describe "when text input events are triggered on the hidden input element", ->
      describe "when there is no selection", ->
        it "inserts the typed character at the cursor position, both in the buffer and the pre element", ->
          editor.setCursorPosition(row: 1, column: 6)

          expect(editor.getCurrentLine().charAt(6)).not.toBe 'q'

          editor.hiddenInput.textInput 'q'

          expect(editor.getCurrentLine().charAt(6)).toBe 'q'
          expect(editor.getCursorPosition()).toEqual(row: 1, column: 7)
          expect(editor.lines.find('pre:eq(1)')).toHaveText editor.getCurrentLine()

      describe "when there is a selection", ->
        it "replaces the selected text with the typed text", ->
          editor.selection.setRange(new Range([1, 6], [2, 4]))
          editor.hiddenInput.textInput 'q'
          expect(buffer.getLine(1)).toBe '  var qif (items.length <= 1) return items;'

    describe "when return is pressed", ->
      describe "when the cursor is at the beginning of a line", ->
        it "inserts an empty line before it", ->
          editor.setCursorPosition(row: 1, column: 0)

          editor.trigger keydownEvent('enter')

          expect(editor.lines.find('pre:eq(1)')).toHaveHtml '&nbsp;'
          expect(editor.getCursorPosition()).toEqual(row: 2, column: 0)

      describe "when the cursor is in the middle of a line", ->
        it "splits the current line to form a new line", ->
          editor.setCursorPosition(row: 1, column: 6)

          originalLine = editor.lines.find('pre:eq(1)').text()
          lineBelowOriginalLine = editor.lines.find('pre:eq(2)').text()
          editor.trigger keydownEvent('enter')

          expect(editor.lines.find('pre:eq(1)')).toHaveText originalLine[0...6]
          expect(editor.lines.find('pre:eq(2)')).toHaveText originalLine[6..]
          expect(editor.lines.find('pre:eq(3)')).toHaveText lineBelowOriginalLine
          expect(editor.getCursorPosition()).toEqual(row: 2, column: 0)

      describe "when the cursor is on the end of a line", ->
        it "inserts an empty line after it", ->
          editor.setCursorPosition(row: 1, column: buffer.getLine(1).length)

          editor.trigger keydownEvent('enter')

          expect(editor.lines.find('pre:eq(2)')).toHaveHtml '&nbsp;'
          expect(editor.getCursorPosition()).toEqual(row: 2, column: 0)

    describe "when backspace is pressed", ->
      describe "when the cursor is on the middle of the line", ->
        it "removes the character before the cursor", ->
          editor.setCursorPosition(row: 1, column: 7)
          expect(buffer.getLine(1)).toBe "  var sort = function(items) {"

          editor.trigger keydownEvent('backspace')

          line = buffer.getLine(1)
          expect(line).toBe "  var ort = function(items) {"
          expect(editor.lines.find('pre:eq(1)')).toHaveText line
          expect(editor.getCursorPosition()).toEqual {row: 1, column: 6}

      describe "when the cursor is at the beginning of a line", ->
        it "joins it with the line above", ->
          originalLine0 = buffer.getLine(0)
          expect(originalLine0).toBe "var quicksort = function () {"
          expect(buffer.getLine(1)).toBe "  var sort = function(items) {"

          editor.setCursorPosition(row: 1, column: 0)
          editor.trigger keydownEvent('backspace')

          line0 = buffer.getLine(0)
          line1 = buffer.getLine(1)
          expect(line0).toBe "var quicksort = function () {  var sort = function(items) {"
          expect(line1).toBe "    if (items.length <= 1) return items;"

          expect(editor.lines.find('pre:eq(0)')).toHaveText line0
          expect(editor.lines.find('pre:eq(1)')).toHaveText line1
          expect(editor.getCursorPosition()).toEqual {row: 0, column: originalLine0.length}

      describe "when the cursor is at the first column of the first line", ->
        it "does nothing, but doesn't raise an error", ->
          editor.setCursorPosition(row: 0, column: 0)
          editor.trigger keydownEvent('backspace')

      describe "when there is a selection", ->
        it "deletes the selection, but not the character before it", ->
          editor.selection.setRange(new Range([0,5], [0,9]))
          editor.trigger keydownEvent('backspace')
          expect(editor.buffer.getLine(0)).toBe 'var qsort = function () {'

    describe "when delete is pressed", ->
      describe "when the cursor is on the middle of a line", ->
        it "deletes the character following the cursor", ->
          editor.setCursorPosition([1, 6])
          editor.trigger keydownEvent('delete')
          expect(buffer.getLine(1)).toBe '  var ort = function(items) {'

      describe "when the cursor is on the end of a line", ->
        it "joins the line with the following line", ->
          editor.setCursorPosition([1, buffer.getLine(1).length])
          editor.trigger keydownEvent('delete')
          expect(buffer.getLine(1)).toBe '  var sort = function(items) {    if (items.length <= 1) return items;'

      describe "when there is a selection", ->
        it "deletes the selection, but not the character following it", ->
          editor.selection.setRange(new Range([1,6], [1,8]))
          editor.trigger keydownEvent 'delete'
          expect(buffer.getLine(1)).toBe '  var rt = function(items) {'

      describe "when the cursor is on the last column of the last line", ->
        it "does nothing, but doesn't raise an error", ->
          editor.setCursorPosition([12, buffer.getLine(12).length])
          editor.trigger keydownEvent('delete')
          expect(buffer.getLine(12)).toBe '};'

    describe "when multiple lines are removed from the buffer (regression)", ->
      it "removes all of them from the dom", ->
        buffer.change(new Range([6, 24], [12, 0]), '')
        expect(editor.find('.line').length).toBe 7
        expect(editor.find('.line:eq(6)').text()).toBe(buffer.getLine(6))

  describe "when the editor is attached to the dom", ->
    it "calculates line height and char width and updates the pixel position of the cursor", ->
      expect(editor.lineHeight).toBeNull()
      expect(editor.charWidth).toBeNull()
      editor.setCursorPosition(row: 2, column: 2)

      editor.attachToDom()

      expect(editor.lineHeight).not.toBeNull()
      expect(editor.charWidth).not.toBeNull()
      expect(editor.getCursor().position().top).toBe(2 * editor.lineHeight)
      expect(editor.getCursor().position().left).toBe(2 * editor.charWidth)

    it "is focused", ->
      editor.attachToDom()
      expect(editor).toMatchSelector ":has(:focus)"

  describe "when the editor is focused", ->
    it "focuses the hidden input", ->
      editor.attachToDom()
      editor.focus()
      expect(editor).not.toMatchSelector ':focus'
      expect(editor.hiddenInput).toMatchSelector ':focus'

  describe ".setBuffer(buffer)", ->
    it "sets the cursor to the beginning of the file", ->
      expect(editor.getCursorPosition()).toEqual(row: 0, column: 0)

  describe ".clipPosition(point)", ->
    it "selects the nearest valid position to the given point", ->
      expect(editor.clipPosition(row: 1000, column: 0)).toEqual(row: buffer.numLines() - 1, column: 0)
      expect(editor.clipPosition(row: -5, column: 0)).toEqual(row: 0, column: 0)
      expect(editor.clipPosition(row: 1, column: 10000)).toEqual(row: 1, column: buffer.getLine(1).length)
      expect(editor.clipPosition(row: 1, column: -5)).toEqual(row: 1, column: 0)


