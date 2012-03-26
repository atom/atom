Buffer = require 'buffer'
Editor = require 'editor'
Range = require 'range'
$ = require 'jquery'
{$$} = require 'space-pen'
_ = require 'underscore'
fs = require 'fs'

describe "Editor", ->
  buffer = null
  editor = null

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    editor = new Editor
    editor.autoIndent = false
    editor.enableKeymap()
    editor.setBuffer(buffer)
    editor.isFocused = true

  describe "construction", ->
    it "assigns an empty buffer and correctly handles text input (regression coverage)", ->
      editor = new Editor
      expect(editor.buffer.path).toBeUndefined()
      expect(editor.lines.find('.line').length).toBe 1
      editor.insertText('x')
      expect(editor.lines.find('.line').length).toBe 1

  describe "text rendering", ->
    it "creates a line element for each line in the buffer with the html-escaped text of the line", ->
      expect(editor.lines.find('.line').length).toEqual(buffer.numLines())
      expect(buffer.lineForRow(2)).toContain('<')
      expect(editor.lines.find('.line:eq(2)').html()).toContain '&lt;'

      # renders empty lines with a non breaking space
      expect(buffer.lineForRow(10)).toBe ''
      expect(editor.lines.find('.line:eq(10)').html()).toBe '&nbsp;'

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

        # verify that re-highlighting can occur below the changed line
        buffer.insert([5,0], "/* */")
        buffer.insert([1,0], "/*")
        expect(editor.lines.find('.line:eq(2) span:eq(0)')).toMatchSelector '.comment'

    describe "when soft-wrap is enabled", ->
      beforeEach ->
        otherEditor = new Editor()
        otherEditor.setBuffer editor.buffer
        otherEditor.attachToDom()
        charWidth = otherEditor.charWidth
        linesPositionLeft = otherEditor.lines.position().left
        otherEditor.remove()
        editor.width(charWidth * 50 + linesPositionLeft)
        editor.setSoftWrap(true)
        editor.attachToDom()

        expect(editor.renderer.maxLineLength).toBe 50

      it "wraps lines that are too long to fit within the editor's width, adjusting cursor positioning accordingly", ->
        expect(editor.lines.find('.line').length).toBe 16
        expect(editor.lines.find('.line:eq(3)').text()).toBe "    var pivot = items.shift(), current, left = [], "
        expect(editor.lines.find('.line:eq(4)').text()).toBe "right = [];"

        editor.cursor.setBufferPosition([3, 51])
        expect(editor.cursor.offset()).toEqual(editor.lines.find('.line:eq(4)').offset())

        editor.cursor.setBufferPosition([4, 0])
        expect(editor.cursor.offset()).toEqual(editor.lines.find('.line:eq(5)').offset())

        editor.getSelection().setBufferRange(new Range([6, 30], [6, 55]))
        [region1, region2] = editor.getSelection().regions
        expect(region1.offset().top).toBe(editor.lines.find('.line:eq(7)').offset().top)
        expect(region2.offset().top).toBe(editor.lines.find('.line:eq(8)').offset().top)

      it "handles changes to wrapped lines correctly", ->
        buffer.insert([6, 28], '1234567')
        expect(editor.lines.find('.line:eq(7)').text()).toBe '      current < pivot ? left1234567.push(current) '
        expect(editor.lines.find('.line:eq(8)').text()).toBe ': right.push(current);'
        expect(editor.lines.find('.line:eq(9)').text()).toBe '    }'

      it "changes the max line length and repositions the cursor when the window size changes", ->
        editor.setCursorBufferPosition([3, 60])
        setEditorWidthInChars(editor, 40)
        $(window).trigger 'resize'
        expect(editor.lines.find('.line').length).toBe 19
        expect(editor.lines.find('.line:eq(4)').text()).toBe "left = [], right = [];"
        expect(editor.lines.find('.line:eq(5)').text()).toBe "    while(items.length > 0) {"
        expect(editor.bufferPositionForScreenPosition(editor.getCursorScreenPosition())).toEqual [3, 60]

      it "unwraps lines and cancels window resize listener when softwrap is disabled", ->
        editor.toggleSoftWrap()
        expect(editor.lines.find('.line:eq(3)').text()).toBe '    var pivot = items.shift(), current, left = [], right = [];'

        spyOn(editor, 'setMaxLineLength')
        $(window).trigger 'resize'
        expect(editor.setMaxLineLength).not.toHaveBeenCalled()

      it "allows the cursor to move down to the last line", ->
        _.times editor.getLastScreenRow(), -> editor.moveCursorDown()
        expect(editor.getCursorScreenPosition()).toEqual [editor.getLastScreenRow(), 0]
        editor.moveCursorDown()
        expect(editor.getCursorScreenPosition()).toEqual [editor.getLastScreenRow(), 2]

      it "allows the cursor to move up to a shorter soft wrapped line", ->
        editor.setCursorScreenPosition([11, 15])
        editor.moveCursorUp()
        expect(editor.getCursorScreenPosition()).toEqual [10, 10]
        editor.moveCursorUp()
        editor.moveCursorUp()
        expect(editor.getCursorScreenPosition()).toEqual [8, 15]

      it "it allows the cursor to wrap when moving horizontally past the beginning / end of a wrapped line", ->
        editor.setCursorScreenPosition([11, 0])
        editor.moveCursorLeft()
        expect(editor.getCursorScreenPosition()).toEqual [10, 10]

        editor.moveCursorRight()
        expect(editor.getCursorScreenPosition()).toEqual [11, 0]

  describe "gutter rendering", ->
    it "creates a line number element for each line in the buffer", ->
      expect(editor.gutter.find('.line-number').length).toEqual(buffer.numLines())
      expect(editor.gutter.find('.line-number:first').text()).toBe "1"
      expect(editor.gutter.find('.line-number:last').text()).toBe "13"

    it "updates line numbers when lines are inserted or removed", ->
      expect(editor.gutter.find('.line-number').length).toEqual 13

      buffer.insert([0, 0], "a new line\n")
      expect(editor.gutter.find('.line-number').length).toEqual 14
      expect(editor.gutter.find('.line-number:last').text()).toBe "14"

      buffer.deleteRow(0)
      buffer.deleteRow(0)
      expect(editor.gutter.find('.line-number').length).toEqual 12
      expect(editor.gutter.find('.line-number:last').text()).toBe "12"

    describe "when wrapping is on", ->
      it "renders a • instead of line number for wrapped portions of lines", ->
        editor.setMaxLineLength(50)
        expect(editor.gutter.find('.line-number:eq(3)').text()).toBe '4'
        expect(editor.gutter.find('.line-number:eq(4)').text()).toBe '•'
        expect(editor.gutter.find('.line-number:eq(5)').text()).toBe '5'

        expect(editor.gutter.find('.line-number:eq(7)').text()).toBe '7'
        expect(editor.gutter.find('.line-number:eq(8)').text()).toBe '•'
        expect(editor.gutter.find('.line-number:eq(9)').text()).toBe '8'

    describe "when there are folds", ->
      it "skips line numbers", ->
        editor.createFold([[3, 10], [5, 1]])
        expect(editor.gutter.find('.line-number:eq(3)').text()).toBe '4'
        expect(editor.gutter.find('.line-number:eq(4)').text()).toBe '7'

    describe "when there is a fold on the last screen line of a wrapped line", ->
      it "renders line numbers correctly when the fold is destroyed (regression)", ->
        editor.setMaxLineLength(50)
        fold = editor.createFold([[3, 52], [3, 56]])
        fold.destroy()
        # console.log editor.renderer.bufferRowsForScreenRows()
        expect(editor.gutter.find('.line-number:last').text()).toBe '13'

    it "adds a drop shadow when the horizontal scroller is scrolled to the right", ->
      editor.attachToDom()
      editor.width(100)

      expect(editor.gutter).not.toHaveClass('drop-shadow')

      editor.horizontalScroller.scrollLeft(10)
      editor.horizontalScroller.trigger('scroll')

      expect(editor.gutter).toHaveClass('drop-shadow')

      editor.horizontalScroller.scrollLeft(0)
      editor.horizontalScroller.trigger('scroll')

      expect(editor.gutter).not.toHaveClass('drop-shadow')

  describe "cursor movement", ->
    describe ".setCursorScreenPosition({row, column})", ->
      beforeEach ->
        editor.attachToDom()
        editor.setCursorScreenPosition(row: 2, column: 2)

      it "moves the cursor to the character at the given row and column", ->
        expect(editor.getCursor().position()).toEqual(top: 2 * editor.lineHeight, left: 2 * editor.charWidth)

      describe "if soft-wrap is enabled", ->
        beforeEach ->
          setEditorWidthInChars(editor, 20)
          editor.setSoftWrap(true)

    describe "when the arrow keys are pressed", ->
      it "moves the cursor by a single row/column", ->
        editor.trigger keydownEvent('right')
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 1)

        editor.trigger keydownEvent('down')
        expect(editor.getCursorScreenPosition()).toEqual(row: 1, column: 1)

        editor.trigger keydownEvent('left')
        expect(editor.getCursorScreenPosition()).toEqual(row: 1, column: 0)

        editor.trigger keydownEvent('up')
        expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

    describe "vertical movement", ->
      describe "auto-scrolling", ->
        beforeEach ->
          editor.attachToDom()
          editor.focus()
          editor.vScrollMargin = 3

        it "scrolls the buffer with the specified scroll margin when cursor approaches the end of the screen", ->
          editor.height(editor.lineHeight * 10)

          _.times 6, -> editor.moveCursorDown()
          window.advanceClock()
          expect(editor.scrollTop()).toBe(0)

          editor.moveCursorDown()
          window.advanceClock()
          expect(editor.scrollTop()).toBe(editor.lineHeight)

          editor.moveCursorDown()
          window.advanceClock()
          expect(editor.scrollTop()).toBe(editor.lineHeight * 2)

          _.times 3, -> editor.moveCursorUp()
          window.advanceClock()
          expect(editor.scrollTop()).toBe(editor.lineHeight * 2)

          editor.moveCursorUp()
          window.advanceClock()
          expect(editor.scrollTop()).toBe(editor.lineHeight)

          editor.moveCursorUp()
          window.advanceClock()
          expect(editor.scrollTop()).toBe(0)

        it "reduces scroll margins when there isn't enough height to maintain them and scroll smoothly", ->
          editor.height(editor.lineHeight * 5)

          _.times 3, -> editor.moveCursorDown()
          window.advanceClock()
          expect(editor.scrollTop()).toBe(editor.lineHeight)

          editor.moveCursorUp()
          window.advanceClock()
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
          editor.setCursorScreenPosition(row: 6, column: 32)

          editor.moveCursorUp()
          expect(editor.getCursorScreenPosition().column).toBe lineLengths[5]

          editor.moveCursorUp()
          expect(editor.getCursorScreenPosition().column).toBe lineLengths[4]

          editor.moveCursorUp()
          expect(editor.getCursorScreenPosition().column).toBe 32

        it "retains the goal column when moving down", ->
          editor.setCursorScreenPosition(row: 3, column: lineLengths[3])

          editor.moveCursorDown()
          expect(editor.getCursorScreenPosition().column).toBe lineLengths[4]

          editor.moveCursorDown()
          expect(editor.getCursorScreenPosition().column).toBe lineLengths[5]

          editor.moveCursorDown()
          expect(editor.getCursorScreenPosition().column).toBe lineLengths[3]

        it "clears the goal column when the cursor is set", ->
          # set a goal column by moving down
          editor.setCursorScreenPosition(row: 3, column: lineLengths[3])
          editor.moveCursorDown()
          expect(editor.getCursorScreenPosition().column).not.toBe 6

          # clear the goal column by explicitly setting the cursor position
          editor.setCursorScreenColumn(6)
          expect(editor.getCursorScreenPosition().column).toBe 6

          editor.moveCursorDown()
          expect(editor.getCursorScreenPosition().column).toBe 6

      describe "when up is pressed on the first line", ->
        it "moves the cursor to the beginning of the line, but retains the goal column", ->
          editor.setCursorScreenPosition(row: 0, column: 4)
          editor.moveCursorUp()
          expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

          editor.moveCursorDown()
          expect(editor.getCursorScreenPosition()).toEqual(row: 1, column: 4)

      describe "when down is pressed on the last line", ->
        it "moves the cursor to the end of line, but retains the goal column", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.lineForRow(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setCursorScreenPosition(row: lastLineIndex, column: 1)
          editor.moveCursorDown()
          expect(editor.getCursorScreenPosition()).toEqual(row: lastLineIndex, column: lastLine.length)

          editor.moveCursorUp()
          expect(editor.getCursorScreenPosition().column).toBe 1

        it "retains a goal column of 0", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.lineForRow(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setCursorScreenPosition(row: lastLineIndex, column: 0)
          editor.moveCursorDown()
          editor.moveCursorUp()
          expect(editor.getCursorScreenPosition().column).toBe 0

    describe "horizontal movement", ->
      describe "auto-scrolling", ->
        charWidth = null
        beforeEach ->
          editor.attachToDom()
          {charWidth} = editor
          editor.hScrollMargin = 5

        it "scrolls horizontally to keep the cursor on screen", ->
          setEditorWidthInChars(editor, 30)

          # moving right
          editor.setCursorScreenPosition([2, 24])
          window.advanceClock()
          expect(editor.horizontalScroller.scrollLeft()).toBe 0

          editor.setCursorScreenPosition([2, 25])
          window.advanceClock()
          expect(editor.horizontalScroller.scrollLeft()).toBe charWidth

          editor.setCursorScreenPosition([2, 28])
          window.advanceClock()
          expect(editor.horizontalScroller.scrollLeft()).toBe charWidth * 4

          # moving left
          editor.setCursorScreenPosition([2, 9])
          window.advanceClock()
          expect(editor.horizontalScroller.scrollLeft()).toBe charWidth * 4

          editor.setCursorScreenPosition([2, 8])
          window.advanceClock()
          expect(editor.horizontalScroller.scrollLeft()).toBe charWidth * 3

          editor.setCursorScreenPosition([2, 5])
          window.advanceClock()
          expect(editor.horizontalScroller.scrollLeft()).toBe 0

        it "reduces scroll margins when there isn't enough width to maintain them and scroll smoothly", ->
          editor.hScrollMargin = 6
          setEditorWidthInChars(editor, 7)

          editor.setCursorScreenPosition([2, 3])
          window.advanceClock()
          expect(editor.horizontalScroller.scrollLeft()).toBe(0)

          editor.setCursorScreenPosition([2, 4])
          window.advanceClock()
          expect(editor.horizontalScroller.scrollLeft()).toBe(charWidth)

          editor.setCursorScreenPosition([2, 3])
          window.advanceClock()
          expect(editor.horizontalScroller.scrollLeft()).toBe(0)

        describe "when soft-wrap is on", ->
          beforeEach ->
            editor.setSoftWrap(true)

          it "does not scroll the buffer horizontally", ->
            editor.width(charWidth * 30)

            # moving right
            editor.setCursorScreenPosition([2, 24])
            expect(editor.horizontalScroller.scrollLeft()).toBe 0

            editor.setCursorScreenPosition([2, 25])
            expect(editor.horizontalScroller.scrollLeft()).toBe 0

            editor.setCursorScreenPosition([2, 28])
            expect(editor.horizontalScroller.scrollLeft()).toBe 0

            # moving left
            editor.setCursorScreenPosition([2, 9])
            expect(editor.horizontalScroller.scrollLeft()).toBe 0

            editor.setCursorScreenPosition([2, 8])
            expect(editor.horizontalScroller.scrollLeft()).toBe 0

            editor.setCursorScreenPosition([2, 5])
            expect(editor.horizontalScroller.scrollLeft()).toBe 0

      describe "when left is pressed on the first column", ->
        describe "when there is a previous line", ->
          it "wraps to the end of the previous line", ->
            editor.setCursorScreenPosition(row: 1, column: 0)
            editor.moveCursorLeft()
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: buffer.lineForRow(0).length)

        describe "when the cursor is on the first line", ->
          it "remains in the same position (0,0)", ->
            editor.setCursorScreenPosition(row: 0, column: 0)
            editor.moveCursorLeft()
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

      describe "when right is pressed on the last column", ->
        describe "when there is a subsequent line", ->
          it "wraps to the beginning of the next line", ->
            editor.setCursorScreenPosition(row: 0, column: buffer.lineForRow(0).length)
            editor.moveCursorRight()
            expect(editor.getCursorScreenPosition()).toEqual(row: 1, column: 0)

        describe "when the cursor is on the last line", ->
          it "remains in the same position", ->
            lastLineIndex = buffer.getLines().length - 1
            lastLine = buffer.lineForRow(lastLineIndex)
            expect(lastLine.length).toBeGreaterThan(0)

            lastPosition = { row: lastLineIndex, column: lastLine.length }
            editor.setCursorScreenPosition(lastPosition)
            editor.moveCursorRight()

            expect(editor.getCursorScreenPosition()).toEqual(lastPosition)

    describe "when a mousedown event occurs in the editor", ->
      beforeEach ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

      describe "when soft-wrap and is enabled and code is folded", ->
        beforeEach ->
          setEditorWidthInChars(editor, 50)
          editor.setSoftWrap(true)
          editor.createFold(new Range([3, 3], [3, 7]))

        describe "when it is a single click", ->
          it "re-positions the cursor from the clicked screen position to the corresponding buffer position", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
            editor.lines.trigger mousedownEvent(editor: editor, point: [4, 7])
            expect(editor.getCursorBufferPosition()).toEqual(row: 3, column: 58)

        describe "when it is a double click", ->
          it "selects the word under the cursor", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
            editor.lines.trigger mousedownEvent(editor: editor, point: [4, 3], originalEvent: {detail: 1})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [4, 3], originalEvent: {detail: 2})
            expect(editor.getSelectedText()).toBe "right"

        describe "when it is clicked more then twice (triple, quadruple, etc...)", ->
          it "selects the line under the cursor", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

            # Triple click
            editor.lines.trigger mousedownEvent(editor: editor, point: [4, 3], originalEvent: {detail: 1})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [4, 3], originalEvent: {detail: 2})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [4, 3], originalEvent: {detail: 3})
            editor.lines.trigger 'mouseup'
            expect(editor.getSelectedText()).toBe "    var pivot = items.shift(), current, left = [], right = [];"

            # Quad click
            editor.lines.trigger mousedownEvent(editor: editor, point: [8, 3], originalEvent: {detail: 1})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [8, 3], originalEvent: {detail: 2})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [8, 3], originalEvent: {detail: 3})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [8, 3], originalEvent: {detail: 4})
            editor.lines.trigger 'mouseup'

            expect(editor.getSelectedText()).toBe "      current < pivot ? left.push(current) : right.push(current);"

      describe "when soft-wrap is disabled", ->
        describe "when it is a single click", ->
          it "re-positions the cursor to the clicked row / column", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

            editor.lines.trigger mousedownEvent(editor: editor, point: [3, 10])
            expect(editor.getCursorScreenPosition()).toEqual(row: 3, column: 10)

          describe "when the lines are scrolled to the right", ->
            it "re-positions the cursor on the clicked location", ->
              setEditorWidthInChars(editor, 30)
              expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
              editor.lines.trigger mousedownEvent(editor: editor, point: [3, 30]) # scrolls lines to the right
              editor.lines.trigger mousedownEvent(editor: editor, point: [3, 50])
              expect(editor.getCursorBufferPosition()).toEqual(row: 3, column: 50)

        describe "when it is a double click", ->
          it "selects the word under the cursor", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)
            editor.lines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 1})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [0, 8], originalEvent: {detail: 2})
            editor.lines.trigger 'mouseup'
            expect(editor.getSelectedText()).toBe "quicksort"

        describe "when it is clicked more then twice (triple, quadruple, etc...)", ->
          it "selects the line under the cursor", ->
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

            # Triple click
            editor.lines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 1})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 2})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [1, 8], originalEvent: {detail: 3})
            editor.lines.trigger 'mouseup'
            expect(editor.getSelectedText()).toBe "  var sort = function(items) {"

            # Quad click
            editor.lines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 1})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 2})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 3})
            editor.lines.trigger 'mouseup'
            editor.lines.trigger mousedownEvent(editor: editor, point: [2, 3], originalEvent: {detail: 4})
            editor.lines.trigger 'mouseup'
            expect(editor.getSelectedText()).toBe "    if (items.length <= 1) return items;"

  describe "auto indent/outdent", ->
    beforeEach ->
      editor.autoIndent = true

    describe "when editing a line that spans a single screen line", ->
      describe "when a newline is inserted", ->
        it "indents cursor based on the indentation of previous buffer line", ->
          editor.setCursorBufferPosition([1, 30])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(2)).toEqual("    ")

      describe "when a newline is inserted following a fold placeholder", ->
        it "indents cursor based on the indentation of previous buffer line", ->
          editor.createFold([[1, 10], [1, 30]])
          editor.setCursorBufferPosition([1, 30])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(2)).toEqual("    ")

      describe "when text beginning with a newline is inserted", ->
        it "indents cursor based on the indentation of previous buffer line", ->
          editor.setCursorBufferPosition([4, 29])
          editor.insertText("\nvar thisIsCool")
          expect(editor.buffer.lineForRow(5)).toEqual("      var thisIsCool")

      describe "when text that closes a scope entered", ->
        it "outdents the text", ->
          editor.setCursorBufferPosition([1, 30])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(2)).toEqual("    ")
          editor.insertText("}")
          expect(editor.buffer.lineForRow(2)).toEqual("  }")
          expect(editor.getCursorBufferPosition().column).toBe 3

    describe "when editing a line that spans multiple screen lines", ->
      beforeEach ->
        editor.setSoftWrap(true, 50)

      describe "when newline is inserted", ->
        it "indents cursor based on the indentation of previous buffer line", ->
          editor.setCursorBufferPosition([4, 29])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(5)).toEqual("      ")

      describe "when text that closes a scope entered", ->
        it "outdents the text", ->
          editor.setCursorBufferPosition([4, 29])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(5)).toEqual("      ")
          editor.insertText("}")
          expect(editor.buffer.lineForRow(5)).toEqual("    }")
          expect(editor.getCursorBufferPosition().column).toBe 5

  describe "selection", ->
    selection = null

    beforeEach ->
      selection = editor.getSelection()

    describe "when the arrow keys are pressed with the shift modifier", ->
      it "expands the selection up to the cursor's new location", ->
        editor.setCursorScreenPosition(row: 1, column: 6)

        expect(selection.isEmpty()).toBeTruthy()

        editor.trigger keydownEvent('right', shiftKey: true)

        expect(selection.isEmpty()).toBeFalsy()
        range = selection.getScreenRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 1, column: 7)

        editor.trigger keydownEvent('right', shiftKey: true)
        range = selection.getScreenRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 1, column: 8)

        editor.trigger keydownEvent('down', shiftKey: true)
        range = selection.getScreenRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 2, column: 8)

        editor.trigger keydownEvent('left', shiftKey: true)
        range = selection.getScreenRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 2, column: 7)

        editor.trigger keydownEvent('up', shiftKey: true)
        range = selection.getScreenRange()
        expect(range.start).toEqual(row: 1, column: 6)
        expect(range.end).toEqual(row: 1, column: 7)

    describe "when the arrow keys are pressed without the shift modifier", ->
      makeNonEmpty = ->
        selection.setBufferRange(new Range({row: 1, column: 2}, {row: 1, column: 5}))
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
        editor.lines.trigger mousedownEvent(editor: editor, point: [4, 10])

        # moving changes selection
        editor.lines.trigger mousemoveEvent(editor: editor, point: [5, 27])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editor.lines.trigger mousemoveEvent(editor: editor, point: [8, 8])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

      it "creates a selection from word underneath double click to mouse cursor's location ", ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

        # double click
        editor.lines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 1})
        $(document).trigger 'mouseup'
        editor.lines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 2})

        # moving changes selection
        editor.lines.trigger mousemoveEvent(editor: editor, point: [5, 27])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 4})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editor.lines.trigger mousemoveEvent(editor: editor, point: [8, 8])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 4})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)


      it "creates a selection from line underneath triple click to mouse cursor's location ", ->
        editor.attachToDom()
        editor.css(position: 'absolute', top: 10, left: 10)

        # double click
        editor.lines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 1})
        $(document).trigger 'mouseup'
        editor.lines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 2})
        $(document).trigger 'mouseup'
        editor.lines.trigger mousedownEvent(editor: editor, point: [4, 7], originalEvent: {detail: 3})

        # moving changes selection
        editor.lines.trigger mousemoveEvent(editor: editor, point: [5, 27])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 0})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editor.lines.trigger mousemoveEvent(editor: editor, point: [8, 8])

        range = editor.getSelection().getScreenRange()
        expect(range.start).toEqual({row: 4, column: 0})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

  fdescribe "multiple cursor placement", ->
    it "places multiple cursor with meta-click", ->
      editor.attachToDom()
      editor.lines.trigger mousedownEvent(editor: editor, point: [3, 0])
      editor.lines.trigger mousedownEvent(editor: editor, point: [6, 0], metaKey: true)

      [cursor1, cursor2] = editor.find('.cursor').map -> $(this).view()
      expect(cursor1.position()).toEqual(top: 3 * editor.lineHeight, left: 0)
      expect(cursor1.getBufferPosition()).toEqual [3, 0]
      expect(cursor2.position()).toEqual(top: 6 * editor.lineHeight, left: 0)
      expect(cursor2.getBufferPosition()).toEqual [6, 0]

    describe "inserting text", ->
      describe "when cursors are on the same line", ->
        describe "when inserting newlines", ->
          it "breaks the line into three lines at the cursor locations", ->
            editor.setCursorScreenPosition([3, 13])
            editor.addCursorAtScreenPosition([3, 38])

            editor.insertText('\n')

            expect(editor.lineForBufferRow(3)).toBe "    var pivot"
            expect(editor.lineForBufferRow(4)).toBe " = items.shift(), current"
            expect(editor.lineForBufferRow(5)).toBe ", left = [], right = [];"
            expect(editor.lineForBufferRow(6)).toBe "    while(items.length > 0) {"

            [cursor1, cursor2] = editor.compositeCursor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [4, 0]
            expect(cursor2.getBufferPosition()).toEqual [5, 0]

      describe "when cursors are on different lines", ->
        describe "when inserting characters other than newlines", ->
          it "inserts text for all cursors", ->
            editor.setCursorScreenPosition([3, 0])
            editor.addCursorAtScreenPosition([6, 0])

            editor.insertText("abc")
            expect(editor.lineForBufferRow(3)).toBe "abc    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineForBufferRow(6)).toBe "abc      current < pivot ? left.push(current) : right.push(current);"

            [cursor1, cursor2] = editor.compositeCursor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [3,3]
            expect(cursor2.getBufferPosition()).toEqual [6,3]

        describe "when inserting newlines", ->
          it "inserts newlines for all cursors", ->
            editor.setCursorScreenPosition([3, 0])
            editor.addCursorAtScreenPosition([6, 0])

            editor.insertText("\n")
            expect(editor.lineForBufferRow(3)).toBe ""
            expect(editor.lineForBufferRow(4)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineForBufferRow(5)).toBe "    while(items.length > 0) {"
            expect(editor.lineForBufferRow(6)).toBe "      current = items.shift();"
            expect(editor.lineForBufferRow(7)).toBe ""
            expect(editor.lineForBufferRow(8)).toBe "      current < pivot ? left.push(current) : right.push(current);"
            expect(editor.lineForBufferRow(9)).toBe "    }"

            [cursor1, cursor2] = editor.compositeCursor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [4,0]
            expect(cursor2.getBufferPosition()).toEqual [8,0]

    describe "backspace", ->
      describe "when cursors are on the same line", ->
        it "removes the characters preceding each cursor", ->
          editor.setCursorScreenPosition([3, 13])
          editor.addCursorAtScreenPosition([3, 38])

          editor.backspace()

          expect(editor.lineForBufferRow(3)).toBe "    var pivo = items.shift(), curren, left = [], right = [];"

          [cursor1, cursor2] = editor.compositeCursor.getCursors()
          expect(cursor1.getBufferPosition()).toEqual [3, 12]
          expect(cursor2.getBufferPosition()).toEqual [3, 36]

          [selection1, selection2] = editor.compositeSelection.getSelections()
          expect(selection1.isEmpty()).toBeTruthy()
          expect(selection2.isEmpty()).toBeTruthy()

      describe "when cursors are on different lines", ->
        it "removes the characters preceding each cursor", ->
          editor.setCursorScreenPosition([3, 13])
          editor.addCursorAtScreenPosition([4, 10])

          editor.backspace()

          expect(editor.lineForBufferRow(3)).toBe "    var pivo = items.shift(), current, left = [], right = [];"
          expect(editor.lineForBufferRow(4)).toBe "    whileitems.length > 0) {"

          [cursor1, cursor2] = editor.compositeCursor.getCursors()
          expect(cursor1.getBufferPosition()).toEqual [3, 12]
          expect(cursor2.getBufferPosition()).toEqual [4, 9]

          [selection1, selection2] = editor.compositeSelection.getSelections()
          expect(selection1.isEmpty()).toBeTruthy()
          expect(selection2.isEmpty()).toBeTruthy()

        describe "when backspacing over newlines", ->
          it "removes the newlines preceding each cursor", ->
            editor.setCursorScreenPosition([3, 0])
            editor.addCursorAtScreenPosition([6, 0])

            editor.backspace()
            expect(editor.lineForBufferRow(2)).toBe "    if (items.length <= 1) return items;    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineForBufferRow(3)).toBe "    while(items.length > 0) {"
            expect(editor.lineForBufferRow(4)).toBe "      current = items.shift();      current < pivot ? left.push(current) : right.push(current);"
            expect(editor.lineForBufferRow(5)).toBe "    }"

            [cursor1, cursor2] = editor.compositeCursor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [2,40]
            expect(cursor2.getBufferPosition()).toEqual [4,30]

    describe "keyboard movement", ->
      it "moves all cursors", ->
        editor.setCursorScreenPosition([3, 13])
        editor.addCursorAtScreenPosition([3, 38])
        editor.addCursorAtScreenPosition([4, 1])
        [cursor1, cursor2, cursor3] = editor.compositeCursor.getCursors()

        editor.moveCursorLeft()
        expect(cursor1.getBufferPosition()).toEqual [3, 12]
        expect(cursor2.getBufferPosition()).toEqual [3, 37]
        expect(cursor3.getBufferPosition()).toEqual [4, 0]

        editor.moveCursorLeft()
        expect(cursor1.getBufferPosition()).toEqual [3, 11]
        expect(cursor2.getBufferPosition()).toEqual [3, 36]
        expect(cursor3.getBufferPosition()).toEqual [3, 62]

        editor.moveCursorRight()
        expect(cursor1.getBufferPosition()).toEqual [3, 12]
        expect(cursor2.getBufferPosition()).toEqual [3, 37]
        expect(cursor3.getBufferPosition()).toEqual [4, 0]

        editor.moveCursorDown()
        expect(cursor1.getBufferPosition()).toEqual [4, 12]
        expect(cursor2.getBufferPosition()).toEqual [4, 29]
        expect(cursor3.getBufferPosition()).toEqual [5, 0]

        editor.moveCursorUp()
        expect(cursor1.getBufferPosition()).toEqual [3, 12]
        expect(cursor2.getBufferPosition()).toEqual [3, 37]
        expect(cursor3.getBufferPosition()).toEqual [4, 0]

    describe "selections", ->
      it "adds an additional selection upon clicking and dragging with the meta-key held down", ->
        editor.attachToDom()
        editor.lines.trigger mousedownEvent(editor: editor, point: [4, 10])
        editor.lines.trigger mousemoveEvent(editor: editor, point: [5, 27])
        editor.lines.trigger 'mouseup'

        editor.lines.trigger mousedownEvent(editor: editor, point: [6, 10], metaKey: true)
        editor.lines.trigger mousemoveEvent(editor: editor, point: [8, 27], metaKey: true)
        editor.lines.trigger 'mouseup'

        selections = editor.compositeSelection.getSelections()
        expect(selections.length).toBe 2
        [selection1, selection2] = selections
        expect(selection1.getScreenRange()).toEqual [[4, 10], [5, 27]]
        expect(selection2.getScreenRange()).toEqual [[6, 10], [8, 27]]

    describe "cursor merging", ->
      it "merges cursors when they overlap due to a buffer change", ->
        editor.setCursorScreenPosition([0, 0])
        editor.addCursorAtScreenPosition([0, 1])
        editor.addCursorAtScreenPosition([1, 1])

        [cursor1, cursor2, cursor3] = editor.compositeCursor.getCursors()
        expect(editor.compositeCursor.getCursors().length).toBe 3

        editor.backspace()
        expect(editor.compositeCursor.getCursors().length).toBe 2
        expect(cursor1.getBufferPosition()).toEqual [0,0]
        expect(cursor3.getBufferPosition()).toEqual [1,0]
        expect(cursor2.parent().length).toBe 0

        editor.insertText "x"
        expect(editor.lineForBufferRow(0)).toBe "xar quicksort = function () {"
        expect(editor.lineForBufferRow(1)).toBe "x var sort = function(items) {"

      it "merges cursors when they overlap due to movement", ->
        editor.setCursorScreenPosition([0, 0])
        editor.addCursorAtScreenPosition([0, 1])

        [cursor1, cursor2] = editor.compositeCursor.getCursors()
        editor.moveCursorLeft()
        expect(editor.compositeCursor.getCursors().length).toBe 1
        expect(cursor2.parent()).not.toExist()
        expect(cursor1.getBufferPosition()).toEqual [0,0]

        editor.addCursorAtScreenPosition([1, 0])
        [cursor1, cursor2] = editor.compositeCursor.getCursors()

        editor.moveCursorUp()
        expect(editor.compositeCursor.getCursors().length).toBe 1
        expect(cursor2.parent()).not.toExist()
        expect(cursor1.getBufferPosition()).toEqual [0,0]

        editor.setCursorScreenPosition([12, 2])
        editor.addCursorAtScreenPosition([12, 1])
        [cursor1, cursor2] = editor.compositeCursor.getCursors()

        editor.moveCursorRight()
        expect(editor.compositeCursor.getCursors().length).toBe 1
        expect(cursor2.parent()).not.toExist()
        expect(cursor1.getBufferPosition()).toEqual [12,2]

        editor.addCursorAtScreenPosition([11, 2])
        [cursor1, cursor2] = editor.compositeCursor.getCursors()

        editor.moveCursorDown()
        expect(editor.compositeCursor.getCursors().length).toBe 1
        expect(cursor2.parent()).not.toExist()
        expect(cursor1.getBufferPosition()).toEqual [12,2]

      it "merges cursors when the mouse is clicked without the meta-key", ->
        editor.attachToDom()
        editor.setCursorScreenPosition([0, 0])
        editor.addCursorAtScreenPosition([0, 1])

        [cursor1, cursor2] = editor.compositeCursor.getCursors()
        editor.lines.trigger mousedownEvent(editor: editor, point: [4, 7])
        expect(editor.compositeCursor.getCursors().length).toBe 1
        expect(cursor2.parent()).not.toExist()
        expect(cursor1.getBufferPosition()).toEqual [4, 7]

        editor.lines.trigger mousemoveEvent(editor: editor, point: [5, 27])

        selections = editor.compositeSelection.getSelections()
        expect(selections.length).toBe 1
        expect(selections[0].getBufferRange()).toEqual [[4,7], [5,27]]

  describe "buffer manipulation", ->
    describe "when text input events are triggered on the hidden input element", ->
      describe "when there is no selection", ->
        it "inserts the typed character at the cursor position, both in the buffer and the pre element", ->
          editor.setCursorScreenPosition(row: 1, column: 6)

          expect(editor.getCurrentBufferLine().charAt(6)).not.toBe 'q'

          editor.hiddenInput.textInput 'q'

          expect(editor.getCurrentBufferLine().charAt(6)).toBe 'q'
          expect(editor.getCursorScreenPosition()).toEqual(row: 1, column: 7)
          expect(editor.lines.find('.line:eq(1)')).toHaveText editor.getCurrentBufferLine()

        it "does not update the cursor position if the editor is not focused", ->
          editor.isFocused = false
          editor.buffer.insert([5, 0], 'blah')
          expect(editor.getCursorScreenPosition()).toEqual [0, 0]

      describe "when there is a selection", ->
        it "replaces the selected text with the typed text", ->
          editor.getSelection().setBufferRange(new Range([1, 6], [2, 4]))
          editor.hiddenInput.textInput 'q'
          expect(buffer.lineForRow(1)).toBe '  var qif (items.length <= 1) return items;'

    describe "when return is pressed", ->
      describe "when the cursor is at the beginning of a line", ->
        it "inserts an empty line before it", ->
          editor.setCursorScreenPosition(row: 1, column: 0)

          editor.trigger keydownEvent('enter')

          expect(editor.lines.find('.line:eq(1)')).toHaveHtml '&nbsp;'
          expect(editor.getCursorScreenPosition()).toEqual(row: 2, column: 0)

      describe "when the cursor is in the middle of a line", ->
        it "splits the current line to form a new line", ->
          editor.setCursorScreenPosition(row: 1, column: 6)

          originalLine = editor.lines.find('.line:eq(1)').text()
          lineBelowOriginalLine = editor.lines.find('.line:eq(2)').text()
          editor.trigger keydownEvent('enter')

          expect(editor.lines.find('.line:eq(1)')).toHaveText originalLine[0...6]
          expect(editor.lines.find('.line:eq(2)')).toHaveText originalLine[6..]
          expect(editor.lines.find('.line:eq(3)')).toHaveText lineBelowOriginalLine
          expect(editor.getCursorScreenPosition()).toEqual(row: 2, column: 0)

      describe "when the cursor is on the end of a line", ->
        it "inserts an empty line after it", ->
          editor.setCursorScreenPosition(row: 1, column: buffer.lineForRow(1).length)

          editor.trigger keydownEvent('enter')

          expect(editor.lines.find('.line:eq(2)')).toHaveHtml '&nbsp;'
          expect(editor.getCursorScreenPosition()).toEqual(row: 2, column: 0)

    describe "when backspace is pressed", ->
      describe "when the cursor is on the middle of the line", ->
        it "removes the character before the cursor", ->
          editor.setCursorScreenPosition(row: 1, column: 7)
          expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"

          editor.trigger keydownEvent('backspace')

          line = buffer.lineForRow(1)
          expect(line).toBe "  var ort = function(items) {"
          expect(editor.lines.find('.line:eq(1)')).toHaveText line
          expect(editor.getCursorScreenPosition()).toEqual {row: 1, column: 6}

      describe "when the cursor is at the beginning of a line", ->
        it "joins it with the line above", ->
          originalLine0 = buffer.lineForRow(0)
          expect(originalLine0).toBe "var quicksort = function () {"
          expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"

          editor.setCursorScreenPosition(row: 1, column: 0)
          editor.trigger keydownEvent('backspace')

          line0 = buffer.lineForRow(0)
          line1 = buffer.lineForRow(1)
          expect(line0).toBe "var quicksort = function () {  var sort = function(items) {"
          expect(line1).toBe "    if (items.length <= 1) return items;"

          expect(editor.lines.find('.line:eq(0)')).toHaveText line0
          expect(editor.lines.find('.line:eq(1)')).toHaveText line1
          expect(editor.getCursorScreenPosition()).toEqual {row: 0, column: originalLine0.length}

      describe "when the cursor is at the first column of the first line", ->
        it "does nothing, but doesn't raise an error", ->
          editor.setCursorScreenPosition(row: 0, column: 0)
          editor.trigger keydownEvent('backspace')

      describe "when there is a selection", ->
        it "deletes the selection, but not the character before it", ->
          editor.getSelection().setBufferRange(new Range([0,5], [0,9]))
          editor.trigger keydownEvent('backspace')
          expect(editor.buffer.lineForRow(0)).toBe 'var qsort = function () {'

    describe "when delete is pressed", ->
      describe "when the cursor is on the middle of a line", ->
        it "deletes the character following the cursor", ->
          editor.setCursorScreenPosition([1, 6])
          editor.trigger keydownEvent('delete')
          expect(buffer.lineForRow(1)).toBe '  var ort = function(items) {'

      describe "when the cursor is on the end of a line", ->
        it "joins the line with the following line", ->
          editor.setCursorScreenPosition([1, buffer.lineForRow(1).length])
          editor.trigger keydownEvent('delete')
          expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {    if (items.length <= 1) return items;'

      describe "when there is a selection", ->
        it "deletes the selection, but not the character following it", ->
          editor.getSelection().setBufferRange(new Range([1,6], [1,8]))
          editor.trigger keydownEvent 'delete'
          expect(buffer.lineForRow(1)).toBe '  var rt = function(items) {'

      describe "when the cursor is on the last column of the last line", ->
        it "does nothing, but doesn't raise an error", ->
          editor.setCursorScreenPosition([12, buffer.lineForRow(12).length])
          editor.trigger keydownEvent('delete')
          expect(buffer.lineForRow(12)).toBe '};'

    describe "when undo/redo events are triggered on the editor", ->
      it "undoes/redoes the last change", ->
        buffer.insert [0, 0], "foo"
        editor.trigger 'undo'
        expect(buffer.lineForRow(0)).not.toContain "foo"

        editor.trigger 'redo'
        expect(buffer.lineForRow(0)).toContain "foo"

    describe "when multiple lines are removed from the buffer (regression)", ->
      it "removes all of them from the dom", ->
        buffer.change(new Range([6, 24], [12, 0]), '')
        expect(editor.find('.line').length).toBe 7
        expect(editor.find('.line:eq(6)').text()).toBe(buffer.lineForRow(6))

  describe "when the editor is attached to the dom", ->
    it "calculates line height and char width and updates the pixel position of the cursor", ->
      expect(editor.lineHeight).toBeNull()
      expect(editor.charWidth).toBeNull()
      editor.setCursorScreenPosition(row: 2, column: 2)

      editor.attachToDom()

      expect(editor.lineHeight).not.toBeNull()
      expect(editor.charWidth).not.toBeNull()
      expect(editor.getCursor().offset()).toEqual pagePixelPositionForPoint(editor, [2, 2])

    it "is focused", ->
      editor.attachToDom()
      expect(editor).toMatchSelector ":has(:focus)"

    it "unsubscribes from the buffer when it is removed from the dom", ->
      buffer = new Buffer
      previousSubscriptionCount = buffer.subscriptionCount()

      editor.attachToDom()
      editor.setBuffer(buffer)

      expect(buffer.subscriptionCount()).toBeGreaterThan previousSubscriptionCount
      expect($('.editor')).toExist()
      editor.remove()
      expect(buffer.subscriptionCount()).toBe previousSubscriptionCount
      expect($('.editor')).not.toExist()

  describe "when the editor recieves focused", ->
    it "focuses the hidden input", ->
      editor.attachToDom()
      editor.focus()
      expect(editor).not.toMatchSelector ':focus'
      expect(editor.hiddenInput).toMatchSelector ':focus'

  describe "when the hidden input is focused / unfocused", ->
    it "assigns the isFocused flag on the editor and also adds/removes the .focused css class", ->
      editor.attachToDom()
      editor.isFocused = false
      editor.hiddenInput.focus()
      expect(editor.isFocused).toBeTruthy()
      expect(editor).toHaveClass('focused')

      editor.hiddenInput.focusout()
      expect(editor.isFocused).toBeFalsy()
      expect(editor).not.toHaveClass('focused')

  describe ".setBuffer(buffer)", ->
    it "sets the cursor to the beginning of the file", ->
      expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

    it "recalls the cursor position and scroll position when the same buffer is re-assigned", ->
      editor.attachToDom()
      editor.height(editor.lineHeight * 5)
      editor.width(editor.charWidth * 30)
      editor.setCursorScreenPosition([8, 28])
      advanceClock()

      previousScrollTop = editor.scrollTop()
      previousScrollLeft = editor.horizontalScroller.scrollLeft()

      editor.setBuffer(new Buffer)
      expect(editor.getCursorScreenPosition()).toEqual [0, 0]
      expect(editor.scrollTop()).toBe 0
      expect(editor.horizontalScroller.scrollLeft()).toBe 0

      editor.setBuffer(buffer)
      expect(editor.getCursorScreenPosition()).toEqual [8, 28]
      expect(editor.scrollTop()).toBe previousScrollTop
      expect(editor.horizontalScroller.scrollLeft()).toBe previousScrollLeft

    it "recalls the undo history of the buffer when it is re-assigned", ->
      editor.insertText('xyz')

      otherBuffer = new Buffer
      editor.setBuffer(otherBuffer)
      editor.insertText('abc')
      expect(otherBuffer.lineForRow(0)).toBe 'abc'
      editor.undo()
      expect(otherBuffer.lineForRow(0)).toBe ''

      editor.setBuffer(buffer)
      editor.undo()
      expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {'
      editor.redo()
      expect(buffer.lineForRow(0)).toBe 'xyzvar quicksort = function () {'

      editor.setBuffer(otherBuffer)
      editor.redo()
      expect(otherBuffer.lineForRow(0)).toBe 'abc'

    it "fully unsubscribes from the previously assigned buffer", ->
      otherBuffer = new Buffer
      previousSubscriptionCount = otherBuffer.subscriptionCount()

      editor.setBuffer(otherBuffer)
      expect(otherBuffer.subscriptionCount()).toBeGreaterThan previousSubscriptionCount

      editor.setBuffer(buffer)
      expect(otherBuffer.subscriptionCount()).toBe previousSubscriptionCount

  describe ".clipScreenPosition(point)", ->
    it "selects the nearest valid position to the given point", ->
      expect(editor.clipScreenPosition(row: 1000, column: 0)).toEqual(row: buffer.getLastRow(), column: buffer.lineForRow(buffer.getLastRow()).length)
      expect(editor.clipScreenPosition(row: -5, column: 0)).toEqual(row: 0, column: 0)
      expect(editor.clipScreenPosition(row: 1, column: 10000)).toEqual(row: 1, column: buffer.lineForRow(1).length)
      expect(editor.clipScreenPosition(row: 1, column: -5)).toEqual(row: 1, column: 0)

  describe "cut, copy & paste", ->
    beforeEach ->
      $native.writeToPasteboard('first')
      expect($native.readFromPasteboard()).toBe 'first'

    describe "when a cut event is triggered", ->
      it "removes the selected text from the buffer and places it on the pasteboard", ->
        editor.getSelection().setBufferRange new Range([0,4], [0,9])
        editor.trigger "cut"
        expect(editor.buffer.lineForRow(0)).toBe "var sort = function () {"
        expect($native.readFromPasteboard()).toBe 'quick'

    describe "when a copy event is triggered", ->
      it "copies selected text onto the clipboard", ->
        editor.getSelection().setBufferRange new Range([0,4], [0, 13])
        editor.trigger "copy"
        expect($native.readFromPasteboard()).toBe 'quicksort'

    describe "when a paste event is triggered", ->
      it "pastes text into the buffer", ->
        editor.setCursorScreenPosition [0, 4]
        editor.trigger "paste"
        expect(editor.buffer.lineForRow(0)).toBe "var firstquicksort = function () {"

        expect(editor.buffer.lineForRow(1)).toBe "  var sort = function(items) {"
        editor.getSelection().setBufferRange new Range([1,6], [1,10])
        editor.trigger "paste"
        expect(editor.buffer.lineForRow(1)).toBe "  var first = function(items) {"

  describe "folding", ->
    describe "when a fold-selection event is triggered", ->
      it "folds the selected text and moves the cursor to just after the placeholder, then treats the placeholder as a single character", ->
        editor.getSelection().setBufferRange(new Range([4, 29], [7, 4]))
        editor.trigger 'fold-selection'

        expect(editor.lines.find('.line:eq(4)').find('.fold-placeholder')).toExist()
        expect(editor.lines.find('.line:eq(5)').text()).toBe '    return sort(left).concat(pivot).concat(sort(right));'

        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(editor.getCursorScreenPosition()).toEqual [4, 32]

        editor.setCursorScreenPosition([9, 2])
        expect(editor.getCursorScreenPosition()).toEqual [9, 2]

        buffer.insert([9, 4], 'x')
        expect(editor.getCursorScreenPosition()).toEqual [6, 5]
        expect(editor.getCursorBufferPosition()).toEqual [9, 5]

        editor.setCursorScreenPosition([4, 30])
        expect(editor.getCursorScreenPosition()).toEqual [4, 29]
        editor.moveCursorRight()
        expect(editor.getCursorScreenPosition()).toEqual [4, 32]

    describe "when a fold placeholder is clicked", ->
      it "removes the associated fold and places the cursor at its beginning", ->
        editor.getSelection().setBufferRange(new Range([4, 29], [7, 4]))
        editor.trigger 'fold-selection'

        editor.find('.fold-placeholder .ellipsis').mousedown()

        expect(editor.find('.fold-placeholder')).not.toExist()
        expect(editor.lines.find('.line:eq(5)').text()).toBe '      current = items.shift();'

        expect(editor.getCursorBufferPosition()).toEqual [4, 29]

    describe "when there is nothing on a line except a fold placeholder", ->
      it "follows the placeholder with a non-breaking space to ensure the line has the proper height", ->
        editor.createFold([[1, 0], [1, 30]])
        expect(editor.lines.find('.line:eq(1)').html()).toMatch /&nbsp;$/

  describe ".save()", ->
    describe "when the current buffer has a path", ->
      tempFilePath = null

      beforeEach ->
        tempFilePath = '/tmp/atom-temp.txt'
        editor.setBuffer new Buffer(tempFilePath)
        expect(editor.buffer.path).toBe tempFilePath

      afterEach ->
        expect(fs.remove(tempFilePath))

      it "saves the current buffer to disk", ->
        editor.buffer.setText 'Edited!'
        expect(fs.exists(tempFilePath)).toBeFalsy()

        editor.save()

        expect(fs.exists(tempFilePath)).toBeTruthy()
        expect(fs.read(tempFilePath)).toBe 'Edited!'

    describe "when the current buffer has no path", ->
      selectedFilePath = null
      beforeEach ->
        editor.setBuffer new Buffer()
        expect(editor.buffer.path).toBeUndefined()
        editor.buffer.setText 'Save me to a new path'
        spyOn($native, 'saveDialog').andCallFake -> selectedFilePath

      it "presents a 'save as' dialog", ->
        editor.save()
        expect($native.saveDialog).toHaveBeenCalled()

      describe "when a path is chosen", ->
        it "saves the buffer to the chosen path", ->
          selectedFilePath = '/tmp/temp.txt'

          editor.save()

          expect(fs.exists(selectedFilePath)).toBeTruthy()
          expect(fs.read(selectedFilePath)).toBe 'Save me to a new path'

      describe "when dialog is cancelled", ->
        it "does not save the buffer", ->
          selectedFilePath = null
          editor.save()
          expect(fs.exists(selectedFilePath)).toBeFalsy()

  describe ".spliceLineElements(startRow, rowCount, lineElements)", ->
    elements = null

    beforeEach ->
      elements = $$ ->
        @div "A", class: 'line'
        @div "B", class: 'line'

    describe "when the start row is 0", ->
      describe "when the row count is 0", ->
        it "inserts the given elements before the first row", ->
          editor.spliceLineElements 0, 0, elements

          expect(editor.lines.find('.line:eq(0)').text()).toBe 'A'
          expect(editor.lines.find('.line:eq(1)').text()).toBe 'B'
          expect(editor.lines.find('.line:eq(2)').text()).toBe 'var quicksort = function () {'

      describe "when the row count is > 0", ->
        it "replaces the initial rows with the given elements", ->
          editor.spliceLineElements 0, 2, elements

          expect(editor.lines.find('.line:eq(0)').text()).toBe 'A'
          expect(editor.lines.find('.line:eq(1)').text()).toBe 'B'
          expect(editor.lines.find('.line:eq(2)').text()).toBe '    if (items.length <= 1) return items;'

    describe "when the start row is less than the last row", ->
      describe "when the row count is 0", ->
        it "inserts the elements at the specified location", ->
          editor.spliceLineElements 2, 0, elements

          expect(editor.lines.find('.line:eq(2)').text()).toBe 'A'
          expect(editor.lines.find('.line:eq(3)').text()).toBe 'B'
          expect(editor.lines.find('.line:eq(4)').text()).toBe '    if (items.length <= 1) return items;'

      describe "when the row count is > 0", ->
        it "replaces the elements at the specified location", ->
          editor.spliceLineElements 2, 2, elements

          expect(editor.lines.find('.line:eq(2)').text()).toBe 'A'
          expect(editor.lines.find('.line:eq(3)').text()).toBe 'B'
          expect(editor.lines.find('.line:eq(4)').text()).toBe '    while(items.length > 0) {'

    describe "when the start row is the last row", ->
      it "appends the elements to the end of the lines", ->
        editor.spliceLineElements 13, 0, elements

        expect(editor.lines.find('.line:eq(12)').text()).toBe '};'
        expect(editor.lines.find('.line:eq(13)').text()).toBe 'A'
        expect(editor.lines.find('.line:eq(14)').text()).toBe 'B'
        expect(editor.lines.find('.line:eq(15)')).not.toExist()





