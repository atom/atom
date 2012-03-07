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
    editor = new Editor
    editor.enableKeymap()
    editor.setBuffer(buffer)

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
        linesPositionLeft = otherEditor.linesPositionLeft()
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

        editor.selection.setBufferRange(new Range([6, 30], [6, 55]))
        [region1, region2] = editor.selection.regions
        expect(region1.offset().top).toBe(editor.lines.find('.line:eq(7)').offset().top)
        expect(region2.offset().top).toBe(editor.lines.find('.line:eq(8)').offset().top)

      # Many more tests for change events in the LineWrapper spec
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
        _.times editor.lastRow(), -> editor.moveCursorDown()
        expect(editor.getCursorScreenPosition()).toEqual [editor.lastRow(), 0]
        editor.moveCursorDown()
        expect(editor.getCursorScreenPosition()).toEqual [editor.lastRow(), 2]

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

  describe "cursor movement", ->
    describe ".setCursorScreenPosition({row, column})", ->
      beforeEach ->
        editor.attachToDom()
        editor.setCursorScreenPosition(row: 2, column: 2)

      it "moves the cursor to the character at the given row and column", ->
        { top, left } = editor.lines.offset()
        expect(editor.getCursor().offset()).toEqual(top: top + 2 * editor.lineHeight, left: left + 2 * editor.charWidth)

      it "moves the hidden input element to the position of the cursor to prevent scrolling misbehavior", ->
        { top, left } = editor.lines.offset()
        expect(editor.hiddenInput.position()).toEqual(top: top + 2 * editor.lineHeight, left: left + 2 * editor.charWidth)

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
          editor.setCursorColumn(6)
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
          expect(editor.lines.scrollLeft()).toBe 0

          editor.setCursorScreenPosition([2, 25])
          expect(editor.lines.scrollLeft()).toBe charWidth

          editor.setCursorScreenPosition([2, 28])
          expect(editor.lines.scrollLeft()).toBe charWidth * 4

          # moving left
          editor.setCursorScreenPosition([2, 9])
          expect(editor.lines.scrollLeft()).toBe charWidth * 4

          editor.setCursorScreenPosition([2, 8])
          expect(editor.lines.scrollLeft()).toBe charWidth * 3

          editor.setCursorScreenPosition([2, 5])
          expect(editor.lines.scrollLeft()).toBe 0

        it "reduces scroll margins when there isn't enough width to maintain them and scroll smoothly", ->
          editor.hScrollMargin = 6
          setEditorWidthInChars(editor, 7)

          editor.setCursorScreenPosition([2, 3])
          expect(editor.lines.scrollLeft()).toBe(0)

          editor.setCursorScreenPosition([2, 4])
          expect(editor.lines.scrollLeft()).toBe(charWidth)

          editor.setCursorScreenPosition([2, 3])
          expect(editor.lines.scrollLeft()).toBe(0)

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

  describe "selection", ->
    selection = null

    beforeEach ->
      selection = editor.selection

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

        range = editor.selection.getScreenRange()
        expect(range.start).toEqual({row: 4, column: 10})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editor.lines.trigger mousemoveEvent(editor: editor, point: [8, 8])

        range = editor.selection.getScreenRange()
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

        range = editor.selection.getScreenRange()
        expect(range.start).toEqual({row: 4, column: 4})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editor.lines.trigger mousemoveEvent(editor: editor, point: [8, 8])

        range = editor.selection.getScreenRange()
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

        range = editor.selection.getScreenRange()
        expect(range.start).toEqual({row: 4, column: 0})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

        # mouse up may occur outside of editor, but still need to halt selection
        $(document).trigger 'mouseup'

        # moving after mouse up should not change selection
        editor.lines.trigger mousemoveEvent(editor: editor, point: [8, 8])

        range = editor.selection.getScreenRange()
        expect(range.start).toEqual({row: 4, column: 0})
        expect(range.end).toEqual({row: 5, column: 27})
        expect(editor.getCursorScreenPosition()).toEqual(row: 5, column: 27)

  describe "buffer manipulation", ->
    describe "when text input events are triggered on the hidden input element", ->
      describe "when there is no selection", ->
        it "inserts the typed character at the cursor position, both in the buffer and the pre element", ->
          editor.setCursorScreenPosition(row: 1, column: 6)

          expect(editor.getCurrentLine().charAt(6)).not.toBe 'q'

          editor.hiddenInput.textInput 'q'

          expect(editor.getCurrentLine().charAt(6)).toBe 'q'
          expect(editor.getCursorScreenPosition()).toEqual(row: 1, column: 7)
          expect(editor.lines.find('.line:eq(1)')).toHaveText editor.getCurrentLine()

      describe "when there is a selection", ->
        it "replaces the selected text with the typed text", ->
          editor.selection.setBufferRange(new Range([1, 6], [2, 4]))
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
          editor.selection.setBufferRange(new Range([0,5], [0,9]))
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
          editor.selection.setBufferRange(new Range([1,6], [1,8]))
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

  describe "when the editor recieves focused", ->
    it "focuses the hidden input", ->
      editor.attachToDom()
      editor.focus()
      expect(editor).not.toMatchSelector ':focus'
      expect(editor.hiddenInput).toMatchSelector ':focus'

  describe ".setBuffer(buffer)", ->
    it "sets the cursor to the beginning of the file", ->
      expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

  describe ".clipScreenPosition(point)", ->
    it "selects the nearest valid position to the given point", ->
      expect(editor.clipScreenPosition(row: 1000, column: 0)).toEqual(row: buffer.lastRow(), column: buffer.lineForRow(buffer.lastRow()).length)
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
        editor.selection.setBufferRange(new Range([4, 29], [7, 4]))
        editor.trigger 'fold-selection'

        expect(editor.lines.find('.line:eq(4)').find('.fold-placeholder')).toExist()
        expect(editor.lines.find('.line:eq(5)').text()).toBe '    return sort(left).concat(pivot).concat(sort(right));'

        expect(editor.selection.isEmpty()).toBeTruthy()
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
        editor.selection.setBufferRange(new Range([4, 29], [7, 4]))
        editor.trigger 'fold-selection'

        editor.find('.fold-placeholder .ellipsis').mousedown()

        expect(editor.find('.fold-placeholder')).not.toExist()
        expect(editor.lines.find('.line:eq(5)').text()).toBe '      current = items.shift();'

        expect(editor.getCursorBufferPosition()).toEqual [4, 29]
