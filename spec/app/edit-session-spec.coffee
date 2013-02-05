Project = require 'project'
Buffer = require 'buffer'
EditSession = require 'edit-session'

describe "EditSession", ->
  [buffer, editSession, lineLengths] = []

  convertToHardTabs = (buffer) ->
    buffer.setText(buffer.getText().replace(/[ ]{2}/g, "\t"))

  beforeEach ->
    editSession = fixturesProject.buildEditSessionForPath('sample.js', autoIndent: false)
    buffer = editSession.buffer
    lineLengths = buffer.getLines().map (line) -> line.length

  afterEach ->
    fixturesProject.destroy()

  describe "cursor", ->
    describe ".getCursor()", ->
      it "returns the most recently created cursor", ->
        editSession.addCursorAtScreenPosition([1, 0])
        lastCursor = editSession.addCursorAtScreenPosition([2, 0])
        expect(editSession.getCursor()).toBe lastCursor

    describe ".setCursorScreenPosition(screenPosition)", ->
      it "clears a goal column established by vertical movement", ->
        # set a goal column by moving down
        editSession.setCursorScreenPosition(row: 3, column: lineLengths[3])
        editSession.moveCursorDown()
        expect(editSession.getCursorScreenPosition().column).not.toBe 6

        # clear the goal column by explicitly setting the cursor position
        editSession.setCursorScreenPosition([4,6])
        expect(editSession.getCursorScreenPosition().column).toBe 6

        editSession.moveCursorDown()
        expect(editSession.getCursorScreenPosition().column).toBe 6

      it "merges multiple cursors", ->
        editSession.setCursorScreenPosition([0, 0])
        editSession.addCursorAtScreenPosition([0, 1])
        [cursor1, cursor2] = editSession.getCursors()
        editSession.setCursorScreenPosition([4, 7])
        expect(editSession.getCursors().length).toBe 1
        expect(editSession.getCursors()).toEqual [cursor1]
        expect(editSession.getCursorScreenPosition()).toEqual [4, 7]

      describe "when soft-wrap is enabled and code is folded", ->
        beforeEach ->
          editSession.setSoftWrapColumn(50)
          editSession.createFold(2, 3)

        it "positions the cursor at the buffer position that corresponds to the given screen position", ->
          editSession.setCursorScreenPosition([9, 0])
          expect(editSession.getCursorBufferPosition()).toEqual [8, 11]

    describe ".moveCursorUp()", ->
      it "moves the cursor up", ->
        editSession.setCursorScreenPosition([2, 2])
        editSession.moveCursorUp()
        expect(editSession.getCursorScreenPosition()).toEqual [1, 2]

      it "retains the goal column across lines of differing length", ->
        expect(lineLengths[6]).toBeGreaterThan(32)
        editSession.setCursorScreenPosition(row: 6, column: 32)

        editSession.moveCursorUp()
        expect(editSession.getCursorScreenPosition().column).toBe lineLengths[5]

        editSession.moveCursorUp()
        expect(editSession.getCursorScreenPosition().column).toBe lineLengths[4]

        editSession.moveCursorUp()
        expect(editSession.getCursorScreenPosition().column).toBe 32

      describe "when the cursor is on the first line", ->
        it "moves the cursor to the beginning of the line, but retains the goal column", ->
          editSession.setCursorScreenPosition(row: 0, column: 4)
          editSession.moveCursorUp()
          expect(editSession.getCursorScreenPosition()).toEqual(row: 0, column: 0)

          editSession.moveCursorDown()
          expect(editSession.getCursorScreenPosition()).toEqual(row: 1, column: 4)

      it "merges cursors when they overlap", ->
        editSession.addCursorAtScreenPosition([1, 0])
        [cursor1, cursor2] = editSession.getCursors()

        editSession.moveCursorUp()
        expect(editSession.getCursors()).toEqual [cursor1]
        expect(cursor1.getBufferPosition()).toEqual [0,0]

    describe ".moveCursorDown()", ->
      it "moves the cursor down", ->
        editSession.setCursorScreenPosition([2, 2])
        editSession.moveCursorDown()
        expect(editSession.getCursorScreenPosition()).toEqual [3, 2]

      it "retains the goal column across lines of differing length", ->
        editSession.setCursorScreenPosition(row: 3, column: lineLengths[3])

        editSession.moveCursorDown()
        expect(editSession.getCursorScreenPosition().column).toBe lineLengths[4]

        editSession.moveCursorDown()
        expect(editSession.getCursorScreenPosition().column).toBe lineLengths[5]

        editSession.moveCursorDown()
        expect(editSession.getCursorScreenPosition().column).toBe lineLengths[3]

      describe "when the cursor is on the last line", ->
        it "moves the cursor to the end of line, but retains the goal column when moving back up", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.lineForRow(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editSession.setCursorScreenPosition(row: lastLineIndex, column: editSession.getTabLength())
          editSession.moveCursorDown()
          expect(editSession.getCursorScreenPosition()).toEqual(row: lastLineIndex, column: lastLine.length)

          editSession.moveCursorUp()
          expect(editSession.getCursorScreenPosition().column).toBe editSession.getTabLength()

        it "retains a goal column of 0 when moving back up", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.lineForRow(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editSession.setCursorScreenPosition(row: lastLineIndex, column: 0)
          editSession.moveCursorDown()
          editSession.moveCursorUp()
          expect(editSession.getCursorScreenPosition().column).toBe 0

      it "merges cursors when they overlap", ->
        editSession.setCursorScreenPosition([12, 2])
        editSession.addCursorAtScreenPosition([11, 2])
        [cursor1, cursor2] = editSession.getCursors()

        editSession.moveCursorDown()
        expect(editSession.getCursors()).toEqual [cursor1]
        expect(cursor1.getBufferPosition()).toEqual [12,2]

    describe ".moveCursorLeft()", ->
      it "moves the cursor by one column to the left", ->
        editSession.setCursorScreenPosition([1, 8])
        editSession.moveCursorLeft()
        expect(editSession.getCursorScreenPosition()).toEqual [1, 7]

      describe "when the cursor is in the first column", ->
        describe "when there is a previous line", ->
          it "wraps to the end of the previous line", ->
            editSession.setCursorScreenPosition(row: 1, column: 0)
            editSession.moveCursorLeft()
            expect(editSession.getCursorScreenPosition()).toEqual(row: 0, column: buffer.lineForRow(0).length)

        describe "when the cursor is on the first line", ->
          it "remains in the same position (0,0)", ->
            editSession.setCursorScreenPosition(row: 0, column: 0)
            editSession.moveCursorLeft()
            expect(editSession.getCursorScreenPosition()).toEqual(row: 0, column: 0)

      describe "when softTabs is enabled and the cursor is preceded by leading whitespace", ->
        it "skips tabLength worth of whitespace at a time", ->
          editSession.setCursorBufferPosition([5, 6])

          editSession.moveCursorLeft()
          expect(editSession.getCursorBufferPosition()).toEqual [5, 4]

      it "merges cursors when they overlap", ->
        editSession.setCursorScreenPosition([0, 0])
        editSession.addCursorAtScreenPosition([0, 1])

        [cursor1, cursor2] = editSession.getCursors()
        editSession.moveCursorLeft()
        expect(editSession.getCursors()).toEqual [cursor1]
        expect(cursor1.getBufferPosition()).toEqual [0,0]

    describe ".moveCursorRight()", ->
      it "moves the cursor by one column to the right", ->
        editSession.setCursorScreenPosition([3, 3])
        editSession.moveCursorRight()
        expect(editSession.getCursorScreenPosition()).toEqual [3, 4]

      describe "when the cursor is on the last column of a line", ->
        describe "when there is a subsequent line", ->
          it "wraps to the beginning of the next line", ->
            editSession.setCursorScreenPosition(row: 0, column: buffer.lineForRow(0).length)
            editSession.moveCursorRight()
            expect(editSession.getCursorScreenPosition()).toEqual(row: 1, column: 0)

        describe "when the cursor is on the last line", ->
          it "remains in the same position", ->
            lastLineIndex = buffer.getLines().length - 1
            lastLine = buffer.lineForRow(lastLineIndex)
            expect(lastLine.length).toBeGreaterThan(0)

            lastPosition = { row: lastLineIndex, column: lastLine.length }
            editSession.setCursorScreenPosition(lastPosition)
            editSession.moveCursorRight()

            expect(editSession.getCursorScreenPosition()).toEqual(lastPosition)

      it "merges cursors when they overlap", ->
        editSession.setCursorScreenPosition([12, 2])
        editSession.addCursorAtScreenPosition([12, 1])
        [cursor1, cursor2] = editSession.getCursors()

        editSession.moveCursorRight()
        expect(editSession.getCursors()).toEqual [cursor1]
        expect(cursor1.getBufferPosition()).toEqual [12,2]

    describe ".moveCursorToTop()", ->
      it "moves the cursor to the top of the buffer", ->
        editSession.setCursorScreenPosition [11,1]
        editSession.addCursorAtScreenPosition [12,0]
        editSession.moveCursorToTop()
        expect(editSession.getCursors().length).toBe 1
        expect(editSession.getCursorBufferPosition()).toEqual [0,0]

    describe ".moveCursorToBottom()", ->
      it "moves the cusor to the bottom of the buffer", ->
        editSession.setCursorScreenPosition [0,0]
        editSession.addCursorAtScreenPosition [1,0]
        editSession.moveCursorToBottom()
        expect(editSession.getCursors().length).toBe 1
        expect(editSession.getCursorBufferPosition()).toEqual [12,2]

    describe ".moveCursorToBeginningOfLine()", ->
      it "moves cursor to the beginning of line", ->
        editSession.setCursorScreenPosition [0,5]
        editSession.addCursorAtScreenPosition [1,7]
        editSession.moveCursorToBeginningOfLine()
        expect(editSession.getCursors().length).toBe 2
        [cursor1, cursor2] = editSession.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0,0]
        expect(cursor2.getBufferPosition()).toEqual [1,0]

    describe ".moveCursorToEndOfLine()", ->
      it "moves cursor to the end of line", ->
        editSession.setCursorScreenPosition [0,0]
        editSession.addCursorAtScreenPosition [1,0]
        editSession.moveCursorToEndOfLine()
        expect(editSession.getCursors().length).toBe 2
        [cursor1, cursor2] = editSession.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0,29]
        expect(cursor2.getBufferPosition()).toEqual [1,30]

    describe ".moveCursorToFirstCharacterOfLine()", ->
      it "moves to the first character of the current line or the beginning of the line if it's already on the first character", ->
        editSession.setCursorScreenPosition [0,5]
        editSession.addCursorAtScreenPosition [1,7]

        editSession.moveCursorToFirstCharacterOfLine()
        [cursor1, cursor2] = editSession.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0,0]
        expect(cursor2.getBufferPosition()).toEqual [1,2]

        editSession.moveCursorToFirstCharacterOfLine()
        expect(cursor1.getBufferPosition()).toEqual [0,0]
        expect(cursor2.getBufferPosition()).toEqual [1,0]

      describe "when triggered ", ->
        it "does not move the cursor", ->
          editSession.setCursorBufferPosition([10, 0])
          editSession.moveCursorToFirstCharacterOfLine()
          expect(editSession.getCursorBufferPosition()).toEqual [10, 0]

    describe ".moveCursorToBeginningOfWord()", ->
      it "moves the cursor to the beginning of the word", ->
        editSession.setCursorBufferPosition [0, 8]
        editSession.addCursorAtBufferPosition [1, 12]
        editSession.addCursorAtBufferPosition [3, 0]
        [cursor1, cursor2, cursor3] = editSession.getCursors()

        editSession.moveCursorToBeginningOfWord()

        expect(cursor1.getBufferPosition()).toEqual [0, 4]
        expect(cursor2.getBufferPosition()).toEqual [1, 11]
        expect(cursor3.getBufferPosition()).toEqual [2, 39]

      it "does not fail at position [0, 0]", ->
        editSession.setCursorBufferPosition([0, 0])
        editSession.moveCursorToBeginningOfWord()

      it "treats lines with only whitespace as a word", ->
        editSession.setCursorBufferPosition([11, 0])
        editSession.moveCursorToBeginningOfWord()
        expect(editSession.getCursorBufferPosition()).toEqual [10, 0]

      it "works when the current line is blank", ->
        editSession.setCursorBufferPosition([10, 0])
        editSession.moveCursorToBeginningOfWord()
        expect(editSession.getCursorBufferPosition()).toEqual [9, 2]

    describe ".moveCursorToEndOfWord()", ->
      it "moves the cursor to the end of the word", ->
        editSession.setCursorBufferPosition [0, 6]
        editSession.addCursorAtBufferPosition [1, 10]
        editSession.addCursorAtBufferPosition [2, 40]
        [cursor1, cursor2, cursor3] = editSession.getCursors()

        editSession.moveCursorToEndOfWord()

        expect(cursor1.getBufferPosition()).toEqual [0, 13]
        expect(cursor2.getBufferPosition()).toEqual [1, 12]
        expect(cursor3.getBufferPosition()).toEqual [3, 7]

      it "does not blow up when there is no next word", ->
        editSession.setCursorBufferPosition [Infinity, Infinity]
        endPosition = editSession.getCursorBufferPosition()
        editSession.moveCursorToEndOfWord()
        expect(editSession.getCursorBufferPosition()).toEqual endPosition

      it "treats lines with only whitespace as a word", ->
        editSession.setCursorBufferPosition([9, 4])
        editSession.moveCursorToEndOfWord()
        expect(editSession.getCursorBufferPosition()).toEqual [10, 0]

      it "works when the current line is blank", ->
        editSession.setCursorBufferPosition([10, 0])
        editSession.moveCursorToEndOfWord()
        expect(editSession.getCursorBufferPosition()).toEqual [11, 8]


    describe ".getCurrentParagraphBufferRange()", ->
      it "returns the buffer range of the current paragraph, delimited by blank lines or the beginning / end of the file", ->
        buffer.setText """
            I am the first paragraph,
          bordered by the beginning of
          the file
          #{'   '}

            I am the second paragraph
          with blank lines above and below
          me.

          I am the last paragraph,
          bordered by the end of the file.
        """

        # in a paragraph
        editSession.setCursorBufferPosition([1, 7])
        expect(editSession.getCurrentParagraphBufferRange()).toEqual [[0, 0], [2, 8]]

        editSession.setCursorBufferPosition([7, 1])
        expect(editSession.getCurrentParagraphBufferRange()).toEqual [[5, 0], [7, 3]]

        editSession.setCursorBufferPosition([9, 10])
        expect(editSession.getCurrentParagraphBufferRange()).toEqual [[9, 0], [10, 32]]

        # between paragraphs
        editSession.setCursorBufferPosition([3, 1])
        expect(editSession.getCurrentParagraphBufferRange()).toBeUndefined()

  describe "selection", ->
    selection = null

    beforeEach ->
      selection = editSession.getSelection()

    describe ".selectUp/Down/Left/Right()", ->
      it "expands each selection to its cursor's new location", ->
        editSession.setSelectedBufferRanges([[[0,9], [0,13]], [[3,16], [3,21]]])
        [selection1, selection2] = editSession.getSelections()

        editSession.selectRight()
        expect(selection1.getBufferRange()).toEqual [[0,9], [0,14]]
        expect(selection2.getBufferRange()).toEqual [[3,16], [3,22]]

        editSession.selectLeft()
        editSession.selectLeft()
        expect(selection1.getBufferRange()).toEqual [[0,9], [0,12]]
        expect(selection2.getBufferRange()).toEqual [[3,16], [3,20]]

        editSession.selectDown()
        expect(selection1.getBufferRange()).toEqual [[0,9], [1,12]]
        expect(selection2.getBufferRange()).toEqual [[3,16], [4,20]]

        editSession.selectUp()
        expect(selection1.getBufferRange()).toEqual [[0,9], [0,12]]
        expect(selection2.getBufferRange()).toEqual [[3,16], [3,20]]

      it "merges selections when they intersect when moving down", ->
        editSession.setSelectedBufferRanges([[[0,9], [0,13]], [[1,10], [1,20]], [[2,15], [3,25]]])
        [selection1, selection2, selection3] = editSession.getSelections()

        editSession.selectDown()
        expect(editSession.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 9], [4, 25]])
        expect(selection1.isReversed()).toBeFalsy()

      it "merges selections when they intersect when moving up", ->
        editSession.setSelectedBufferRanges([[[0,9], [0,13]], [[1,10], [1,20]]], reverse: true)
        [selection1, selection2] = editSession.getSelections()

        editSession.selectUp()
        expect(editSession.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 0], [1, 20]])
        expect(selection1.isReversed()).toBeTruthy()

      it "merges selections when they intersect when moving left", ->
        editSession.setSelectedBufferRanges([[[0,9], [0,13]], [[0,14], [1,20]]], reverse: true)
        [selection1, selection2] = editSession.getSelections()

        editSession.selectLeft()
        expect(editSession.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 8], [1, 20]])
        expect(selection1.isReversed()).toBeTruthy()

      it "merges selections when they intersect when moving right", ->
        editSession.setSelectedBufferRanges([[[0,9], [0,13]], [[0,14], [1,20]]])
        [selection1, selection2] = editSession.getSelections()

        editSession.selectRight()
        expect(editSession.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 9], [1, 21]])
        expect(selection1.isReversed()).toBeFalsy()

    describe ".selectToScreenPosition(screenPosition)", ->
      it "expands the last selection to the given position", ->
        editSession.setSelectedBufferRange([[3, 0], [4, 5]])
        editSession.addCursorAtScreenPosition([5, 6])
        editSession.selectToScreenPosition([6, 2])

        selections = editSession.getSelections()
        expect(selections.length).toBe 2
        [selection1, selection2] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 0], [4, 5]]
        expect(selection2.getScreenRange()).toEqual [[5, 6], [6, 2]]

      it "merges selections if they intersect, maintaining the directionality of the last selection", ->
        editSession.setCursorScreenPosition([4, 10])
        editSession.selectToScreenPosition([5, 27])
        editSession.addCursorAtScreenPosition([3, 10])
        editSession.selectToScreenPosition([6, 27])

        selections = editSession.getSelections()
        expect(selections.length).toBe 1
        [selection1] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 10], [6, 27]]
        expect(selection1.isReversed()).toBeFalsy()

        editSession.addCursorAtScreenPosition([7, 4])
        editSession.selectToScreenPosition([4, 11])

        selections = editSession.getSelections()
        expect(selections.length).toBe 1
        [selection1] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 10], [7, 4]]
        expect(selection1.isReversed()).toBeTruthy()

    describe ".selectToTop()", ->
      it "selects text from cusor position to the top of the buffer", ->
        editSession.setCursorScreenPosition [11,2]
        editSession.addCursorAtScreenPosition [10,0]
        editSession.selectToTop()
        expect(editSession.getCursors().length).toBe 1
        expect(editSession.getCursorBufferPosition()).toEqual [0,0]
        expect(editSession.getSelection().getBufferRange()).toEqual [[0,0], [11,2]]
        expect(editSession.getSelection().isReversed()).toBeTruthy()

    describe ".selectToBottom()", ->
      it "selects text from cusor position to the bottom of the buffer", ->
        editSession.setCursorScreenPosition [10,0]
        editSession.addCursorAtScreenPosition [9,3]
        editSession.selectToBottom()
        expect(editSession.getCursors().length).toBe 1
        expect(editSession.getCursorBufferPosition()).toEqual [12,2]
        expect(editSession.getSelection().getBufferRange()).toEqual [[9,3], [12,2]]
        expect(editSession.getSelection().isReversed()).toBeFalsy()

    describe ".selectAll()", ->
      it "selects the entire buffer", ->
        editSession.selectAll()
        expect(editSession.getSelection().getBufferRange()).toEqual buffer.getRange()

    describe ".selectToBeginningOfLine()", ->
      it "selects text from cusor position to beginning of line", ->
        editSession.setCursorScreenPosition [12,2]
        editSession.addCursorAtScreenPosition [11,3]

        editSession.selectToBeginningOfLine()

        expect(editSession.getCursors().length).toBe 2
        [cursor1, cursor2] = editSession.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [12,0]
        expect(cursor2.getBufferPosition()).toEqual [11,0]

        expect(editSession.getSelections().length).toBe 2
        [selection1, selection2] = editSession.getSelections()
        expect(selection1.getBufferRange()).toEqual [[12,0], [12,2]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[11,0], [11,3]]
        expect(selection2.isReversed()).toBeTruthy()

    describe ".selectToEndOfLine()", ->
      it "selects text from cusor position to end of line", ->
        editSession.setCursorScreenPosition [12,0]
        editSession.addCursorAtScreenPosition [11,3]

        editSession.selectToEndOfLine()

        expect(editSession.getCursors().length).toBe 2
        [cursor1, cursor2] = editSession.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [12,2]
        expect(cursor2.getBufferPosition()).toEqual [11,44]

        expect(editSession.getSelections().length).toBe 2
        [selection1, selection2] = editSession.getSelections()
        expect(selection1.getBufferRange()).toEqual [[12,0], [12,2]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[11,3], [11,44]]
        expect(selection2.isReversed()).toBeFalsy()

    describe ".selectLine()", ->
      it "selects the entire line (including newlines) at given row", ->
         editSession.setCursorScreenPosition([1, 2])
         editSession.selectLine()
         expect(editSession.getSelectedBufferRange()).toEqual [[1,0], [2,0]]
         expect(editSession.getSelectedText()).toBe "  var sort = function(items) {\n"

         editSession.setCursorScreenPosition([12, 2])
         editSession.selectLine()
         expect(editSession.getSelectedBufferRange()).toEqual [[12,0], [12,2]]

    describe ".selectToBeginningOfWord()", ->
      it "selects text from cusor position to beginning of word", ->
        editSession.setCursorScreenPosition [0,13]
        editSession.addCursorAtScreenPosition [3,49]

        editSession.selectToBeginningOfWord()

        expect(editSession.getCursors().length).toBe 2
        [cursor1, cursor2] = editSession.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0,4]
        expect(cursor2.getBufferPosition()).toEqual [3,47]

        expect(editSession.getSelections().length).toBe 2
        [selection1, selection2] = editSession.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0,4], [0,13]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[3,47], [3,49]]
        expect(selection2.isReversed()).toBeTruthy()

    describe ".selectToEndOfWord()", ->
      it "selects text from cusor position to end of word", ->
        editSession.setCursorScreenPosition [0,4]
        editSession.addCursorAtScreenPosition [3,48]

        editSession.selectToEndOfWord()

        expect(editSession.getCursors().length).toBe 2
        [cursor1, cursor2] = editSession.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0,13]
        expect(cursor2.getBufferPosition()).toEqual [3,50]

        expect(editSession.getSelections().length).toBe 2
        [selection1, selection2] = editSession.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0,4], [0,13]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[3,48], [3,50]]
        expect(selection2.isReversed()).toBeFalsy()

    describe ".selectWord()", ->
      describe "when the cursor is inside a word", ->
        it "selects the entire word", ->
          editSession.setCursorScreenPosition([0, 8])
          editSession.selectWord()
          expect(editSession.getSelectedText()).toBe 'quicksort'

      describe "when the cursor is between two words", ->
        it "selects the word the cursor is on", ->
          editSession.setCursorScreenPosition([0, 4])
          editSession.selectWord()
          expect(editSession.getSelectedText()).toBe 'quicksort'

          editSession.setCursorScreenPosition([0, 3])
          editSession.selectWord()
          expect(editSession.getSelectedText()).toBe 'var'


      describe "when the cursor is inside a region of whitespace", ->
        it "selects the whitespace region", ->
          editSession.setCursorScreenPosition([5, 2])
          editSession.selectWord()
          expect(editSession.getSelectedBufferRange()).toEqual [[5, 0], [5, 6]]

          editSession.setCursorScreenPosition([5, 0])
          editSession.selectWord()
          expect(editSession.getSelectedBufferRange()).toEqual [[5, 0], [5, 6]]

      describe "when the cursor is at the end of the text", ->
        it "select the previous word", ->
          editSession.buffer.append 'word'
          editSession.moveCursorToBottom()
          editSession.selectWord()
          expect(editSession.getSelectedBufferRange()).toEqual [[12, 2], [12, 6]]

    describe ".setSelectedBufferRanges(ranges)", ->
      it "clears existing selections and creates selections for each of the given ranges", ->
        editSession.setSelectedBufferRanges([[[2, 2], [3, 3]], [[4, 4], [5, 5]]])
        expect(editSession.getSelectedBufferRanges()).toEqual [[[2, 2], [3, 3]], [[4, 4], [5, 5]]]

        editSession.setSelectedBufferRanges([[[5, 5], [6, 6]]])
        expect(editSession.getSelectedBufferRanges()).toEqual [[[5, 5], [6, 6]]]

      it "merges intersecting selections", ->
        editSession.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 0], [5, 5]]])
        expect(editSession.getSelectedBufferRanges()).toEqual [[[2, 2], [5, 5]]]

      it "recyles existing selection instances", ->
        selection = editSession.getSelection()
        editSession.setSelectedBufferRanges([[[2, 2], [3, 3]], [[4, 4], [5, 5]]])

        [selection1, selection2] = editSession.getSelections()
        expect(selection1).toBe selection
        expect(selection1.getBufferRange()).toEqual [[2, 2], [3, 3]]

      describe "when the preserveFolds option is false (the default)", ->
        it "removes folds that contain the selections", ->
          editSession.setSelectedBufferRange([[0,0], [0,0]])
          editSession.createFold(1, 4)
          editSession.createFold(2, 3)
          editSession.createFold(6, 8)
          editSession.createFold(10, 11)

          editSession.setSelectedBufferRanges([[[2, 2], [3, 3]], [[6, 6], [7, 7]]])
          expect(editSession.lineForScreenRow(1).fold).toBeUndefined()
          expect(editSession.lineForScreenRow(2).fold).toBeUndefined()
          expect(editSession.lineForScreenRow(6).fold).toBeUndefined()
          expect(editSession.lineForScreenRow(10).fold).toBeDefined()

      describe "when the preserve folds option is true", ->
        it "does not remove folds that contain the selections", ->
          editSession.setSelectedBufferRange([[0,0], [0,0]])
          editSession.createFold(1, 4)
          editSession.setSelectedBufferRanges([[[2, 2], [3, 3]]], preserveFolds: true)
          expect(editSession.lineForScreenRow(1).fold).toBeDefined()

    describe "when the cursor is moved while there is a selection", ->
      makeSelection = -> selection.setBufferRange [[1, 2], [1, 5]]

      it "clears the selection", ->
        makeSelection()
        editSession.moveCursorDown()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editSession.moveCursorUp()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editSession.moveCursorLeft()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editSession.moveCursorRight()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editSession.setCursorScreenPosition([3, 3])
        expect(selection.isEmpty()).toBeTruthy()

  describe "buffer manipulation", ->
    describe ".insertText(text)", ->
      describe "when there are multiple empty selections", ->
        describe "when the cursors are on the same line", ->
          it "inserts the given text at the location of each cursor and moves the cursors to the end of each cursor's inserted text", ->
            editSession.setCursorScreenPosition([1, 2])
            editSession.addCursorAtScreenPosition([1, 5])

            editSession.insertText('xxx')

            expect(buffer.lineForRow(1)).toBe '  xxxvarxxx sort = function(items) {'
            [cursor1, cursor2] = editSession.getCursors()

            expect(cursor1.getBufferPosition()).toEqual [1, 5]
            expect(cursor2.getBufferPosition()).toEqual [1, 11]

        describe "when the cursors are on different lines", ->
          it "inserts the given text at the location of each cursor and moves the cursors to the end of each cursor's inserted text", ->
            editSession.setCursorScreenPosition([1, 2])
            editSession.addCursorAtScreenPosition([2, 4])

            editSession.insertText('xxx')

            expect(buffer.lineForRow(1)).toBe '  xxxvar sort = function(items) {'
            expect(buffer.lineForRow(2)).toBe '    xxxif (items.length <= 1) return items;'
            [cursor1, cursor2] = editSession.getCursors()

            expect(cursor1.getBufferPosition()).toEqual [1, 5]
            expect(cursor2.getBufferPosition()).toEqual [2, 7]

      describe "when there are multiple non-empty selections", ->
        describe "when the selections are on the same line", ->
          it "replaces each selection range with the inserted characters", ->
            editSession.setSelectedBufferRanges([[[0,4], [0,13]], [[0,22], [0,24]]])
            editSession.insertText("x")

            [cursor1, cursor2] = editSession.getCursors()
            [selection1, selection2] = editSession.getSelections()

            expect(cursor1.getScreenPosition()).toEqual [0, 5]
            expect(cursor2.getScreenPosition()).toEqual [0, 15]
            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection2.isEmpty()).toBeTruthy()

            expect(editSession.lineForBufferRow(0)).toBe "var x = functix () {"

        describe "when the selections are on different lines", ->
          it "replaces each selection with the given text, clears the selections, and places the cursor at the end of each selection's inserted text", ->
            editSession.setSelectedBufferRanges([[[1, 0], [1, 2]], [[2, 0], [2, 4]]])

            editSession.insertText('xxx')

            expect(buffer.lineForRow(1)).toBe 'xxxvar sort = function(items) {'
            expect(buffer.lineForRow(2)).toBe 'xxxif (items.length <= 1) return items;'
            [selection1, selection2] = editSession.getSelections()

            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection1.cursor.getBufferPosition()).toEqual [1, 3]
            expect(selection2.isEmpty()).toBeTruthy()
            expect(selection2.cursor.getBufferPosition()).toEqual [2, 3]

      describe "when there is a selection that ends on a folded line", ->
        it "destroys the selection", ->
          editSession.createFold(2,4)
          editSession.setSelectedBufferRange([[1,0], [2,0]])
          editSession.insertText('holy cow')
          expect(editSession.lineForScreenRow(2).fold).toBeUndefined()

      describe "when auto-indent is enabled", ->
        describe "when a single newline is inserted", ->
          describe "when the newline is inserted on a line that starts a new level of indentation", ->
            it "auto-indents the new line to one additional level of indentation beyond the preceding line", ->
              editSession.setCursorBufferPosition([1, Infinity])
              editSession.insertText('\n', autoIndent: true)
              expect(editSession.indentationForBufferRow(2)).toBe editSession.indentationForBufferRow(1) + 1

          describe "when the newline is inserted on a normal line", ->
            it "auto-indents the new line to the same level of indentation as the preceding line", ->
              editSession.setCursorBufferPosition([5, 13])
              editSession.insertText('\n', autoIndent: true)
              expect(editSession.indentationForBufferRow(6)).toBe editSession.indentationForBufferRow(5)

        describe "when text without newlines is inserted", ->
          describe "when the current line matches an auto-outdent pattern", ->
            describe "when the preceding line matches an auto-indent pattern", ->
              it "auto-decreases the indentation of the line to match that of the preceding line", ->
                editSession.setCursorBufferPosition([2, 4])
                editSession.insertText('\n', autoIndent: true)
                editSession.setCursorBufferPosition([2, 4])
                expect(editSession.indentationForBufferRow(2)).toBe editSession.indentationForBufferRow(1) + 1
                editSession.insertText('   }', autoIndent: true)
                expect(editSession.indentationForBufferRow(2)).toBe editSession.indentationForBufferRow(1)

            describe "when the preceding does not match an auto-indent pattern", ->
              it "auto-decreases the indentation of the line to be one level below that of the preceding line", ->
                editSession.setCursorBufferPosition([3, Infinity])
                editSession.insertText('\n', autoIndent: true)
                expect(editSession.indentationForBufferRow(4)).toBe editSession.indentationForBufferRow(3)
                editSession.insertText('   }', autoIndent: true)
                expect(editSession.indentationForBufferRow(4)).toBe editSession.indentationForBufferRow(3) - 1

          describe "when the current line does not match an auto-outdent pattern", ->
            it "leaves the line unchanged", ->
              editSession.setCursorBufferPosition([2, 4])
              expect(editSession.indentationForBufferRow(2)).toBe editSession.indentationForBufferRow(1) + 1
              editSession.insertText('foo', autoIndent: true)
              expect(editSession.indentationForBufferRow(2)).toBe editSession.indentationForBufferRow(1) + 1

      describe "when the `normalizeIndent` option is true", ->
        describe "when the inserted text contains no newlines", ->
          it "does not adjust the indentation level of the text", ->
            editSession.setCursorBufferPosition([5, 2])
            editSession.insertText("foo", normalizeIndent: true)
            expect(editSession.lineForBufferRow(5)).toBe "  foo    current = items.shift();"

        describe "when the inserted text contains newlines", ->
          text = null
          beforeEach ->
            editSession.setCursorBufferPosition([2, Infinity])
            text = [
              "    while (true) {"
              "      foo();"
              "    }"
              "  bar();"
            ].join('\n')

          removeLeadingWhitespace = (text) -> text.replace(/^\s*/, '')

          describe "when the cursor is preceded only by whitespace", ->
            describe "when auto-indent is enabled", ->
              describe "when the cursor's current column is less than the suggested indent level", ->
                describe "when the indentBasis is inferred from the first line", ->
                  it "indents all lines relative to the suggested indent", ->
                    editSession.insertText('\n xx', autoIndent: true)
                    editSession.setCursorBufferPosition([3, 1])
                    editSession.insertText(text, normalizeIndent: true, autoIndent: true)

                    expect(editSession.lineForBufferRow(3)).toBe "    while (true) {"
                    expect(editSession.lineForBufferRow(4)).toBe "      foo();"
                    expect(editSession.lineForBufferRow(5)).toBe "    }"
                    expect(editSession.lineForBufferRow(6)).toBe "  bar();xx"

                describe "when an indentBasis is provided", ->
                  it "indents all lines relative to the suggested indent", ->
                    editSession.insertText('\n xx')
                    editSession.setCursorBufferPosition([3, 1])
                    editSession.insertText(removeLeadingWhitespace(text), normalizeIndent: true, indentBasis: 2, autoIndent: true)

                    expect(editSession.lineForBufferRow(3)).toBe "    while (true) {"
                    expect(editSession.lineForBufferRow(4)).toBe "      foo();"
                    expect(editSession.lineForBufferRow(5)).toBe "    }"
                    expect(editSession.lineForBufferRow(6)).toBe "  bar();xx"

                describe "when inserting on a line that has mixed tabs and whitespace in hard tabs mode (regression)", ->
                  it "correctly indents the inserted text", ->
                    editSession.softTabs = false
                    buffer.setText """
                      not indented
                          \tmixed indented
                    """

                    editSession.setCursorBufferPosition([1, 0])
                    editSession.insertText(text, normalizeIndent: true, autoIndent: true)

                    expect(editSession.lineForBufferRow(1)).toBe "\t\t\twhile (true) {"
                    expect(editSession.lineForBufferRow(2)).toBe "\t\t\t\tfoo();"
                    expect(editSession.lineForBufferRow(3)).toBe "\t\t\t}"
                    expect(editSession.lineForBufferRow(4)).toBe "\t\tbar();    \tmixed indented"

                describe "when inserting on a fractionally-indented line in hard tabs mode (regression)", ->
                  it "correctly indents the inserted text", ->
                    editSession.softTabs = false
                    buffer.setText """
                      not indented
                           fractional indentation
                    """

                    editSession.setCursorBufferPosition([1, 0])
                    editSession.insertText(text, normalizeIndent: true, autoIndent: true)

                    expect(editSession.lineForBufferRow(1)).toBe "\t\twhile (true) {"
                    expect(editSession.lineForBufferRow(2)).toBe "\t\t\tfoo();"
                    expect(editSession.lineForBufferRow(3)).toBe "\t\t}"
                    expect(editSession.lineForBufferRow(4)).toBe "\tbar();     fractional indentation"

              describe "when the cursor's current column is greater than the suggested indent level", ->
                describe "when the indentBasis is inferred from the first line", ->
                  it "preserves the current indent level, indenting all lines relative to it", ->
                    editSession.insertText('\n      ')
                    editSession.insertText(text, normalizeIndent: true)

                    expect(editSession.lineForBufferRow(3)).toBe "      while (true) {"
                    expect(editSession.lineForBufferRow(4)).toBe "        foo();"
                    expect(editSession.lineForBufferRow(5)).toBe "      }"
                    expect(editSession.lineForBufferRow(6)).toBe "    bar();"

                describe "when an indentBasis is provided", ->
                  it "preserves the current indent level, indenting all lines relative to it", ->
                    editSession.insertText('\n      ')
                    editSession.insertText(removeLeadingWhitespace(text), normalizeIndent: true, indentBasis: 2)

                    expect(editSession.lineForBufferRow(3)).toBe "      while (true) {"
                    expect(editSession.lineForBufferRow(4)).toBe "        foo();"
                    expect(editSession.lineForBufferRow(5)).toBe "      }"
                    expect(editSession.lineForBufferRow(6)).toBe "    bar();"

            describe "if auto-indent is disabled", ->
              describe "when the indentBasis is inferred from the first line", ->
                it "always normalizes indented lines to the cursor's current indentation level", ->
                  editSession.insertText('\n ')
                  editSession.insertText(text, normalizeIndent: true)

                  expect(editSession.lineForBufferRow(3)).toBe " while (true) {"
                  expect(editSession.lineForBufferRow(4)).toBe "   foo();"
                  expect(editSession.lineForBufferRow(5)).toBe " }"
                  expect(editSession.lineForBufferRow(6)).toBe "bar();"

              describe "when an indentBasis is provided", ->
                it "always normalizes indented lines to the cursor's current indentation level", ->
                  editSession.insertText('\n ')
                  editSession.insertText(removeLeadingWhitespace(text), normalizeIndent: true, indentBasis: 2)

                  expect(editSession.lineForBufferRow(3)).toBe " while (true) {"
                  expect(editSession.lineForBufferRow(4)).toBe "   foo();"
                  expect(editSession.lineForBufferRow(5)).toBe " }"

          describe "when the cursor is preceded by non-whitespace characters", ->
            describe "when the indentBasis is inferred from the first line", ->
              it "normalizes the indentation level of all lines based on the level of the existing first line", ->
                editSession.buffer.delete([[2, 0], [2, 2]])
                editSession.insertText(text, normalizeIndent:true)

                expect(editSession.lineForBufferRow(2)).toBe "  if (items.length <= 1) return items;while (true) {"
                expect(editSession.lineForBufferRow(3)).toBe "    foo();"
                expect(editSession.lineForBufferRow(4)).toBe "  }"
                expect(editSession.lineForBufferRow(5)).toBe "bar();"

            describe "when an indentBasis is provided", ->
              it "normalizes the indentation level of all lines based on the level of the existing first line", ->
                editSession.buffer.delete([[2, 0], [2, 2]])
                editSession.insertText(removeLeadingWhitespace(text), normalizeIndent:true, indentBasis: 2)

                expect(editSession.lineForBufferRow(2)).toBe "  if (items.length <= 1) return items;while (true) {"
                expect(editSession.lineForBufferRow(3)).toBe "    foo();"
                expect(editSession.lineForBufferRow(4)).toBe "  }"
                expect(editSession.lineForBufferRow(5)).toBe "bar();"

    describe ".insertNewline()", ->
      describe "when there is a single cursor", ->
        describe "when the cursor is at the beginning of a line", ->
          it "inserts an empty line before it", ->
            editSession.setCursorScreenPosition(row: 1, column: 0)

            editSession.insertNewline()

            expect(buffer.lineForRow(1)).toBe ''
            expect(editSession.getCursorScreenPosition()).toEqual(row: 2, column: 0)

        describe "when the cursor is in the middle of a line", ->
          it "splits the current line to form a new line", ->
            editSession.setCursorScreenPosition(row: 1, column: 6)
            originalLine = buffer.lineForRow(1)
            lineBelowOriginalLine = buffer.lineForRow(2)

            editSession.insertNewline()

            expect(buffer.lineForRow(1)).toBe originalLine[0...6]
            expect(buffer.lineForRow(2)).toBe originalLine[6..]
            expect(buffer.lineForRow(3)).toBe lineBelowOriginalLine
            expect(editSession.getCursorScreenPosition()).toEqual(row: 2, column: 0)

        describe "when the cursor is on the end of a line", ->
          it "inserts an empty line after it", ->
            editSession.setCursorScreenPosition(row: 1, column: buffer.lineForRow(1).length)

            editSession.insertNewline()

            expect(buffer.lineForRow(2)).toBe ''
            expect(editSession.getCursorScreenPosition()).toEqual(row: 2, column: 0)

      describe "when there are multiple cursors", ->
        describe "when the cursors are on the same line", ->
          it "breaks the line at the cursor locations", ->
            editSession.setCursorScreenPosition([3, 13])
            editSession.addCursorAtScreenPosition([3, 38])

            editSession.insertNewline()

            expect(editSession.lineForBufferRow(3)).toBe "    var pivot"
            expect(editSession.lineForBufferRow(4)).toBe " = items.shift(), current"
            expect(editSession.lineForBufferRow(5)).toBe ", left = [], right = [];"
            expect(editSession.lineForBufferRow(6)).toBe "    while(items.length > 0) {"

            [cursor1, cursor2] = editSession.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [4, 0]
            expect(cursor2.getBufferPosition()).toEqual [5, 0]

        describe "when the cursors are on different lines", ->
          it "inserts newlines at each cursor location", ->
            editSession.setCursorScreenPosition([3, 0])
            editSession.addCursorAtScreenPosition([6, 0])

            editSession.insertText("\n")
            expect(editSession.lineForBufferRow(3)).toBe ""
            expect(editSession.lineForBufferRow(4)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editSession.lineForBufferRow(5)).toBe "    while(items.length > 0) {"
            expect(editSession.lineForBufferRow(6)).toBe "      current = items.shift();"
            expect(editSession.lineForBufferRow(7)).toBe ""
            expect(editSession.lineForBufferRow(8)).toBe "      current < pivot ? left.push(current) : right.push(current);"
            expect(editSession.lineForBufferRow(9)).toBe "    }"

            [cursor1, cursor2] = editSession.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [4,0]
            expect(cursor2.getBufferPosition()).toEqual [8,0]

    describe ".insertNewlineBelow()", ->
      xit "inserts a newline below the cursor's current line, autoindents it, and moves the cursor to the end of the line", ->
        editSession.setAutoIndent(true)
        editSession.insertNewlineBelow()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe "  "
        expect(editSession.getCursorBufferPosition()).toEqual [1, 2]

    describe ".backspace()", ->
      describe "when there is a single cursor", ->
        changeScreenRangeHandler = null

        beforeEach ->
          selection = editSession.getLastSelection()
          changeScreenRangeHandler = jasmine.createSpy('changeScreenRangeHandler')
          selection.on 'screen-range-changed', changeScreenRangeHandler

        describe "when the cursor is on the middle of the line", ->
          it "removes the character before the cursor", ->
            editSession.setCursorScreenPosition(row: 1, column: 7)
            expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"

            editSession.backspace()

            line = buffer.lineForRow(1)
            expect(line).toBe "  var ort = function(items) {"
            expect(editSession.getCursorScreenPosition()).toEqual {row: 1, column: 6}
            expect(changeScreenRangeHandler).toHaveBeenCalled()

        describe "when the cursor is at the beginning of a line", ->
          it "joins it with the line above", ->
            originalLine0 = buffer.lineForRow(0)
            expect(originalLine0).toBe "var quicksort = function () {"
            expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"

            editSession.setCursorScreenPosition(row: 1, column: 0)
            editSession.backspace()

            line0 = buffer.lineForRow(0)
            line1 = buffer.lineForRow(1)
            expect(line0).toBe "var quicksort = function () {  var sort = function(items) {"
            expect(line1).toBe "    if (items.length <= 1) return items;"
            expect(editSession.getCursorScreenPosition()).toEqual [0, originalLine0.length]

            expect(changeScreenRangeHandler).toHaveBeenCalled()

        describe "when the cursor is at the first column of the first line", ->
          it "does nothing, but doesn't raise an error", ->
            editSession.setCursorScreenPosition(row: 0, column: 0)
            editSession.backspace()

        describe "when the cursor is on the first column of a line below a fold", ->
          it "absorbs the current line into the fold", ->
            editSession.setCursorScreenPosition([4,0])
            editSession.foldCurrentRow()
            editSession.setCursorScreenPosition([5,0])
            editSession.backspace()

            expect(buffer.lineForRow(7)).toBe "    }    return sort(left).concat(pivot).concat(sort(right));"
            expect(buffer.lineForRow(8)).toBe "  };"

        describe "when the cursor is in the middle of a line below a fold", ->
          it "backspaces as normal", ->
            editSession.setCursorScreenPosition([4,0])
            editSession.foldCurrentRow()
            editSession.setCursorScreenPosition([5,5])
            editSession.backspace()

            expect(buffer.lineForRow(7)).toBe "    }"
            expect(buffer.lineForRow(8)).toBe "    eturn sort(left).concat(pivot).concat(sort(right));"

        describe "when the cursor is on a folded screen line", ->
          it "deletes all of the folded lines along with the fold", ->
            editSession.setCursorBufferPosition([3, 0])
            editSession.foldCurrentRow()
            editSession.backspace()
            expect(buffer.lineForRow(1)).toBe ""
            expect(buffer.lineForRow(2)).toBe "  return sort(Array.apply(this, arguments));"
            expect(editSession.getCursorScreenPosition()).toEqual [1, 0]

      describe "when there are multiple cursors", ->
        describe "when cursors are on the same line", ->
          it "removes the characters preceding each cursor", ->
            editSession.setCursorScreenPosition([3, 13])
            editSession.addCursorAtScreenPosition([3, 38])

            editSession.backspace()

            expect(editSession.lineForBufferRow(3)).toBe "    var pivo = items.shift(), curren, left = [], right = [];"

            [cursor1, cursor2] = editSession.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [3, 12]
            expect(cursor2.getBufferPosition()).toEqual [3, 36]

            [selection1, selection2] = editSession.getSelections()
            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection2.isEmpty()).toBeTruthy()

        describe "when cursors are on different lines", ->
          describe "when the cursors are in the middle of their lines", ->
            it "removes the characters preceding each cursor", ->
              editSession.setCursorScreenPosition([3, 13])
              editSession.addCursorAtScreenPosition([4, 10])

              editSession.backspace()

              expect(editSession.lineForBufferRow(3)).toBe "    var pivo = items.shift(), current, left = [], right = [];"
              expect(editSession.lineForBufferRow(4)).toBe "    whileitems.length > 0) {"

              [cursor1, cursor2] = editSession.getCursors()
              expect(cursor1.getBufferPosition()).toEqual [3, 12]
              expect(cursor2.getBufferPosition()).toEqual [4, 9]

              [selection1, selection2] = editSession.getSelections()
              expect(selection1.isEmpty()).toBeTruthy()
              expect(selection2.isEmpty()).toBeTruthy()

          describe "when the cursors are on the first column of their lines", ->
            it "removes the newlines preceding each cursor", ->
              editSession.setCursorScreenPosition([3, 0])
              editSession.addCursorAtScreenPosition([6, 0])

              editSession.backspace()
              expect(editSession.lineForBufferRow(2)).toBe "    if (items.length <= 1) return items;    var pivot = items.shift(), current, left = [], right = [];"
              expect(editSession.lineForBufferRow(3)).toBe "    while(items.length > 0) {"
              expect(editSession.lineForBufferRow(4)).toBe "      current = items.shift();      current < pivot ? left.push(current) : right.push(current);"
              expect(editSession.lineForBufferRow(5)).toBe "    }"

              [cursor1, cursor2] = editSession.getCursors()
              expect(cursor1.getBufferPosition()).toEqual [2,40]
              expect(cursor2.getBufferPosition()).toEqual [4,30]

      describe "when there is a single selection", ->
        it "deletes the selection, but not the character before it", ->
          editSession.setSelectedBufferRange([[0,5], [0,9]])
          editSession.backspace()
          expect(editSession.buffer.lineForRow(0)).toBe 'var qsort = function () {'

        describe "when the selection ends on a folded line", ->
          it "destroys the fold", ->
            editSession.setSelectedBufferRange([[3,0], [4,0]])
            editSession.foldBufferRow(4)
            editSession.backspace()

            expect(buffer.lineForRow(3)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
            expect(buffer.lineForRow(4)).toBe "  };"
            expect(editSession.getCursorScreenPosition()).toEqual [3, 0]

      describe "when there are multiple selections", ->
        it "removes all selected text", ->
          editSession.setSelectedBufferRanges([[[0,4], [0,13]], [[0,16], [0,24]]])
          editSession.backspace()
          expect(editSession.lineForBufferRow(0)).toBe 'var  =  () {'

    describe ".backspaceToBeginningOfWord()", ->
      describe "when no text is selected", ->
        it "deletes all text between the cursor and the beginning of the word", ->
          editSession.setCursorBufferPosition([1, 24])
          editSession.addCursorAtBufferPosition([3, 5])
          [cursor1, cursor2] = editSession.getCursors()

          editSession.backspaceToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(ems) {'
          expect(buffer.lineForRow(3)).toBe '    ar pivot = items.shift(), current, left = [], right = [];'
          expect(cursor1.getBufferPosition()).toEqual [1, 22]
          expect(cursor2.getBufferPosition()).toEqual [3, 4]

          editSession.backspaceToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = functionems) {'
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return itemsar pivot = items.shift(), current, left = [], right = [];'
          expect(cursor1.getBufferPosition()).toEqual [1, 21]
          expect(cursor2.getBufferPosition()).toEqual [2, 39]

          editSession.backspaceToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = ems) {'
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return ar pivot = items.shift(), current, left = [], right = [];'
          expect(cursor1.getBufferPosition()).toEqual [1, 13]
          expect(cursor2.getBufferPosition()).toEqual [2, 34]

      describe "when text is selected", ->
        it "deletes only selected text", ->
          editSession.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
          editSession.backspaceToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
          expect(buffer.lineForRow(2)).toBe 'if (items.length <= 1) return items;'

    describe ".backspaceToBeginningOfLine()", ->
      describe "when no text is selected", ->
        it "deletes all text between the cursor and the beginning of the line", ->
          editSession.setCursorBufferPosition([1, 24])
          editSession.addCursorAtBufferPosition([2, 5])
          [cursor1, cursor2] = editSession.getCursors()

          editSession.backspaceToBeginningOfLine()
          expect(buffer.lineForRow(1)).toBe 'ems) {'
          expect(buffer.lineForRow(2)).toBe 'f (items.length <= 1) return items;'
          expect(cursor1.getBufferPosition()).toEqual [1, 0]
          expect(cursor2.getBufferPosition()).toEqual [2, 0]

          editSession.backspaceToBeginningOfLine()
          expect(buffer.lineForRow(1)).toBe 'ems) {'
          expect(cursor1.getBufferPosition()).toEqual [1, 0]

      describe "when text is selected", ->
        it "still deletes all text to begginning of the line", ->
          editSession.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
          editSession.backspaceToBeginningOfLine()
          expect(buffer.lineForRow(1)).toBe 'ems) {'
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;'

    describe ".delete()", ->
      describe "when there is a single cursor", ->
        describe "when the cursor is on the middle of a line", ->
          it "deletes the character following the cursor", ->
            editSession.setCursorScreenPosition([1, 6])
            editSession.delete()
            expect(buffer.lineForRow(1)).toBe '  var ort = function(items) {'

        describe "when the cursor is on the end of a line", ->
          it "joins the line with the following line", ->
            editSession.setCursorScreenPosition([1, buffer.lineForRow(1).length])
            editSession.delete()
            expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {    if (items.length <= 1) return items;'

        describe "when the cursor is on the last column of the last line", ->
          it "does nothing, but doesn't raise an error", ->
            editSession.setCursorScreenPosition([12, buffer.lineForRow(12).length])
            editSession.delete()
            expect(buffer.lineForRow(12)).toBe '};'

        describe "when the cursor is on the end of a line above a fold", ->
          it "only deletes the lines inside the fold", ->
            editSession.foldBufferRow(4)
            editSession.setCursorScreenPosition([3, Infinity])
            cursorPositionBefore = editSession.getCursorScreenPosition()

            editSession.delete()

            expect(buffer.lineForRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(buffer.lineForRow(4)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
            expect(editSession.getCursorScreenPosition()).toEqual cursorPositionBefore

        describe "when the cursor is in the middle a line above a fold", ->
          it "deletes as normal", ->
            editSession.foldBufferRow(4)
            editSession.setCursorScreenPosition([3, 4])
            cursorPositionBefore = editSession.getCursorScreenPosition()

            editSession.delete()

            expect(buffer.lineForRow(3)).toBe "    ar pivot = items.shift(), current, left = [], right = [];"
            expect(editSession.lineForScreenRow(4).fold).toBeDefined()
            expect(editSession.getCursorScreenPosition()).toEqual [3, 4]

        describe "when the cursor is on a folded line", ->
          it "removes the lines contained by the fold", ->
            editSession.setSelectedBufferRange([[2, 0], [2, 0]])
            editSession.createFold(2,4)
            editSession.createFold(2,6)
            oldLine7 = buffer.lineForRow(7)
            oldLine8 = buffer.lineForRow(8)

            editSession.delete()
            expect(editSession.lineForScreenRow(2).text).toBe oldLine7
            expect(editSession.lineForScreenRow(3).text).toBe oldLine8

      describe "when there are multiple cursors", ->
        describe "when cursors are on the same line", ->
          it "removes the characters following each cursor", ->
            editSession.setCursorScreenPosition([3, 13])
            editSession.addCursorAtScreenPosition([3, 38])

            editSession.delete()

            expect(editSession.lineForBufferRow(3)).toBe "    var pivot= items.shift(), current left = [], right = [];"

            [cursor1, cursor2] = editSession.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [3, 13]
            expect(cursor2.getBufferPosition()).toEqual [3, 37]

            [selection1, selection2] = editSession.getSelections()
            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection2.isEmpty()).toBeTruthy()

        describe "when cursors are on different lines", ->
          describe "when the cursors are in the middle of the lines", ->
            it "removes the characters following each cursor", ->
              editSession.setCursorScreenPosition([3, 13])
              editSession.addCursorAtScreenPosition([4, 10])

              editSession.delete()

              expect(editSession.lineForBufferRow(3)).toBe "    var pivot= items.shift(), current, left = [], right = [];"
              expect(editSession.lineForBufferRow(4)).toBe "    while(tems.length > 0) {"

              [cursor1, cursor2] = editSession.getCursors()
              expect(cursor1.getBufferPosition()).toEqual [3, 13]
              expect(cursor2.getBufferPosition()).toEqual [4, 10]

              [selection1, selection2] = editSession.getSelections()
              expect(selection1.isEmpty()).toBeTruthy()
              expect(selection2.isEmpty()).toBeTruthy()

          describe "when the cursors are at the end of their lines", ->
            it "removes the newlines following each cursor", ->
              editSession.setCursorScreenPosition([0, 29])
              editSession.addCursorAtScreenPosition([1, 30])

              editSession.delete()

              expect(editSession.lineForBufferRow(0)).toBe "var quicksort = function () {  var sort = function(items) {    if (items.length <= 1) return items;"

              [cursor1, cursor2] = editSession.getCursors()
              expect(cursor1.getBufferPosition()).toEqual [0,29]
              expect(cursor2.getBufferPosition()).toEqual [0,59]

      describe "when there is a single selection", ->
        it "deletes the selection, but not the character following it", ->
          editSession.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
          editSession.delete()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
          expect(buffer.lineForRow(2)).toBe 'if (items.length <= 1) return items;'
          expect(editSession.getSelection().isEmpty()).toBeTruthy()

      describe "when there are multiple selections", ->
        describe "when selections are on the same line", ->
          it "removes all selected text", ->
            editSession.setSelectedBufferRanges([[[0,4], [0,13]], [[0,16], [0,24]]])
            editSession.delete()
            expect(editSession.lineForBufferRow(0)).toBe 'var  =  () {'

    describe ".deleteToEndOfWord()", ->
      describe "when no text is selected", ->
        it "deletes to the end of the word", ->
          editSession.setCursorBufferPosition([1, 24])
          editSession.addCursorAtBufferPosition([2, 5])
          [cursor1, cursor2] = editSession.getCursors()

          editSession.deleteToEndOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
          expect(buffer.lineForRow(2)).toBe '    i (items.length <= 1) return items;'
          expect(cursor1.getBufferPosition()).toEqual [1, 24]
          expect(cursor2.getBufferPosition()).toEqual [2, 5]

          editSession.deleteToEndOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it {'
          expect(buffer.lineForRow(2)).toBe '    iitems.length <= 1) return items;'
          expect(cursor1.getBufferPosition()).toEqual [1, 24]
          expect(cursor2.getBufferPosition()).toEqual [2, 5]

      describe "when text is selected", ->
        it "deletes only selected text", ->
          editSession.setSelectedBufferRange([[1, 24], [1, 27]])
          editSession.deleteToEndOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'

    describe ".indent()", ->
      describe "when the selection is empty", ->
        describe "when autoIndent is disabled", ->
          describe "if 'softTabs' is true (the default)", ->
            it "inserts 'tabLength' spaces into the buffer", ->
              tabRegex = new RegExp("^[ ]{#{editSession.getTabLength()}}")
              expect(buffer.lineForRow(0)).not.toMatch(tabRegex)
              editSession.indent()
              expect(buffer.lineForRow(0)).toMatch(tabRegex)

          describe "if 'softTabs' is false", ->
            it "insert a \t into the buffer", ->
              editSession.softTabs = false
              expect(buffer.lineForRow(0)).not.toMatch(/^\t/)
              editSession.indent()
              expect(buffer.lineForRow(0)).toMatch(/^\t/)

        describe "when autoIndent is enabled", ->
          describe "when the cursor's column is less than the suggested level of indentation", ->
            describe "when 'softTabs' is true (the default)", ->
              it "moves the cursor to the end of the leading whitespace and inserts enough whitespace to bring the line to the suggested level of indentaion", ->
                buffer.insert([5, 0], "  \n")
                editSession.setCursorBufferPosition [5, 0]
                editSession.indent(autoIndent: true)
                expect(buffer.lineForRow(5)).toMatch /^\s+$/
                expect(buffer.lineForRow(5).length).toBe 6
                expect(editSession.getCursorBufferPosition()).toEqual [5, 6]

            describe "when 'softTabs' is false", ->
              it "moves the cursor to the end of the leading whitespace and inserts enough tabs to bring the line to the suggested level of indentaion", ->
                convertToHardTabs(buffer)
                editSession.softTabs = false
                buffer.insert([5, 0], "\t\n")
                editSession.setCursorBufferPosition [5, 0]
                editSession.indent(autoIndent: true)
                expect(buffer.lineForRow(5)).toMatch /^\t\t\t$/
                expect(editSession.getCursorBufferPosition()).toEqual [5, 3]

          describe "when the line's indent level is greater than the suggested level of indentation", ->
            describe "when 'softTabs' is true (the default)", ->
              it "moves the cursor to the end of the leading whitespace and inserts 'tabLength' spaces into the buffer", ->
                buffer.insert([7, 0], "      \n")
                editSession.setCursorBufferPosition [7, 2]
                editSession.indent(autoIndent: true)
                expect(buffer.lineForRow(7)).toMatch /^\s+$/
                expect(buffer.lineForRow(7).length).toBe 8
                expect(editSession.getCursorBufferPosition()).toEqual [7, 8]

            describe "when 'softTabs' is false", ->
              it "moves the cursor to the end of the leading whitespace and inserts \t into the buffer", ->
                convertToHardTabs(buffer)
                editSession.softTabs = false
                buffer.insert([7, 0], "\t\t\t\n")
                editSession.setCursorBufferPosition [7, 1]
                editSession.indent(autoIndent: true)
                expect(buffer.lineForRow(7)).toMatch /^\t\t\t\t$/
                expect(editSession.getCursorBufferPosition()).toEqual [7, 4]

      describe "when the selection is not empty", ->
        it "indents the selected lines", ->
          editSession.setSelectedBufferRange([[0, 0], [10, 0]])
          selection = editSession.getSelection()
          spyOn(selection, "indentSelectedRows")
          editSession.indent()
          expect(selection.indentSelectedRows).toHaveBeenCalled()

      describe "if editSession.softTabs is false", ->
        it "inserts a tab character into the buffer", ->
          editSession.setSoftTabs(false)
          expect(buffer.lineForRow(0)).not.toMatch(/^\t/)
          editSession.indent()
          expect(buffer.lineForRow(0)).toMatch(/^\t/)
          expect(editSession.getCursorBufferPosition()).toEqual [0, 1]
          expect(editSession.getCursorScreenPosition()).toEqual [0, editSession.getTabLength()]

          editSession.indent()
          expect(buffer.lineForRow(0)).toMatch(/^\t\t/)
          expect(editSession.getCursorBufferPosition()).toEqual [0, 2]
          expect(editSession.getCursorScreenPosition()).toEqual [0, editSession.getTabLength() * 2]

    describe "pasteboard operations", ->
      beforeEach ->
        editSession.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]])

      describe ".cutSelectedText()", ->
        it "removes the selected text from the buffer and places it on the pasteboard", ->
          editSession.cutSelectedText()
          expect(buffer.lineForRow(0)).toBe "var  = function () {"
          expect(buffer.lineForRow(1)).toBe "  var  = function(items) {"

          expect($native.readFromPasteboard()).toBe 'quicksort\nsort'

      describe ".cutToEndOfLine()", ->
        describe "when nothing is selected", ->
          it "cuts up to the end of the line", ->
            editSession.setCursorBufferPosition([2, 20])
            editSession.addCursorAtBufferPosition([3, 20])
            editSession.cutToEndOfLine()
            expect(buffer.lineForRow(2)).toBe '    if (items.length'
            expect(buffer.lineForRow(3)).toBe '    var pivot = item'
            expect(pasteboard.read()[0]).toBe ' <= 1) return items;\ns.shift(), current, left = [], right = [];'

        describe "when text is selected", ->
          it "only cuts the selected text, not to the end of the line", ->
            editSession.setSelectedBufferRanges([[[2,20], [2, 30]], [[3, 20], [3, 20]]])

            editSession.cutToEndOfLine()

            expect(buffer.lineForRow(2)).toBe '    if (items.lengthurn items;'
            expect(buffer.lineForRow(3)).toBe '    var pivot = item'
            expect(pasteboard.read()[0]).toBe ' <= 1) ret\ns.shift(), current, left = [], right = [];'

      describe ".copySelectedText()", ->
        it "copies selected text onto the clipboard", ->
          editSession.copySelectedText()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
          expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"
          expect($native.readFromPasteboard()).toBe 'quicksort\nsort'

      describe ".pasteText()", ->
        it "pastes text into the buffer", ->
          pasteboard.write('first')
          editSession.pasteText()
          expect(editSession.buffer.lineForRow(0)).toBe "var first = function () {"
          expect(buffer.lineForRow(1)).toBe "  var first = function(items) {"

        it "preserves the indent level when copying and pasting multiple lines", ->
          editSession.setSelectedBufferRange([[4, 4], [7, 5]])
          editSession.copySelectedText()
          editSession.setCursorBufferPosition([10, 0])
          editSession.pasteText(autoIndent: true)

          expect(editSession.lineForBufferRow(10)).toBe "  while(items.length > 0) {"
          expect(editSession.lineForBufferRow(11)).toBe "    current = items.shift();"
          expect(editSession.lineForBufferRow(12)).toBe "    current < pivot ? left.push(current) : right.push(current);"
          expect(editSession.lineForBufferRow(13)).toBe "  }"

    describe ".indentSelectedRows()", ->
      describe "when nothing is selected", ->
        describe "when softTabs is enabled", ->
          it "indents line and retains selection", ->
            editSession.setSelectedBufferRange([[0,3], [0,3]])
            editSession.indentSelectedRows()
            expect(buffer.lineForRow(0)).toBe "  var quicksort = function () {"
            expect(editSession.getSelectedBufferRange()).toEqual [[0, 3 + editSession.getTabLength()], [0, 3 + editSession.getTabLength()]]

        describe "when softTabs is disabled", ->
          it "indents line and retains selection", ->
            convertToHardTabs(buffer)
            editSession.softTabs = false
            editSession.setSelectedBufferRange([[0,3], [0,3]])
            editSession.indentSelectedRows()
            expect(buffer.lineForRow(0)).toBe "\tvar quicksort = function () {"
            expect(editSession.getSelectedBufferRange()).toEqual [[0, 3 + 1], [0, 3 + 1]]

      describe "when one line is selected", ->
        describe "when softTabs is enabled", ->
          it "indents line and retains selection", ->
            editSession.setSelectedBufferRange([[0,4], [0,14]])
            editSession.indentSelectedRows()
            expect(buffer.lineForRow(0)).toBe "#{editSession.getTabText()}var quicksort = function () {"
            expect(editSession.getSelectedBufferRange()).toEqual [[0, 4 + editSession.getTabLength()], [0, 14 + editSession.getTabLength()]]

        describe "when softTabs is disabled", ->
          it "indents line and retains selection", ->
            convertToHardTabs(buffer)
            editSession.softTabs = false
            editSession.setSelectedBufferRange([[0,4], [0,14]])
            editSession.indentSelectedRows()
            expect(buffer.lineForRow(0)).toBe "\tvar quicksort = function () {"
            expect(editSession.getSelectedBufferRange()).toEqual [[0, 4 + 1], [0, 14 + 1]]

      describe "when multiple lines are selected", ->
        describe "when softTabs is enabled", ->
          it "indents selected lines (that are not empty) and retains selection", ->
            editSession.setSelectedBufferRange([[9,1], [11,15]])
            editSession.indentSelectedRows()
            expect(buffer.lineForRow(9)).toBe "    };"
            expect(buffer.lineForRow(10)).toBe ""
            expect(buffer.lineForRow(11)).toBe "    return sort(Array.apply(this, arguments));"
            expect(editSession.getSelectedBufferRange()).toEqual [[9, 1 + editSession.getTabLength()], [11, 15 + editSession.getTabLength()]]

         it "does not indent the last row if the selection ends at column 0", ->
           editSession.setSelectedBufferRange([[9,1], [11,0]])
           editSession.indentSelectedRows()
           expect(buffer.lineForRow(9)).toBe "    };"
           expect(buffer.lineForRow(10)).toBe ""
           expect(buffer.lineForRow(11)).toBe "  return sort(Array.apply(this, arguments));"
           expect(editSession.getSelectedBufferRange()).toEqual [[9, 1 + editSession.getTabLength()], [11, 0]]

        describe "when softTabs is disabled", ->
          it "indents selected lines (that are not empty) and retains selection", ->
            convertToHardTabs(buffer)
            editSession.softTabs = false
            editSession.setSelectedBufferRange([[9,1], [11,15]])
            editSession.indentSelectedRows()
            expect(buffer.lineForRow(9)).toBe "\t\t};"
            expect(buffer.lineForRow(10)).toBe ""
            expect(buffer.lineForRow(11)).toBe "\t\treturn sort(Array.apply(this, arguments));"
            expect(editSession.getSelectedBufferRange()).toEqual [[9, 1 + 1], [11, 15 + 1]]

    describe ".outdentSelectedRows()", ->
      describe "when nothing is selected", ->
        it "outdents line and retains selection", ->
          editSession.setSelectedBufferRange([[1,3], [1,3]])
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
          expect(editSession.getSelectedBufferRange()).toEqual [[1, 3 - editSession.getTabLength()], [1, 3 - editSession.getTabLength()]]

        it "outdents when indent is less than a tab length", ->
          editSession.insertText(' ')
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

        it "outdents a single hard tab when indent is multiple hard tabs and and the session is using soft tabs", ->
          editSession.insertText('\t\t')
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "\tvar quicksort = function () {"
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

        it "outdents when a mix of hard tabs and soft tabs are used", ->
          editSession.insertText('\t   ')
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "   var quicksort = function () {"
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe " var quicksort = function () {"
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

      describe "when one line is selected", ->
        it "outdents line and retains editSession", ->
          editSession.setSelectedBufferRange([[1,4], [1,14]])
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
          expect(editSession.getSelectedBufferRange()).toEqual [[1, 4 - editSession.getTabLength()], [1, 14 - editSession.getTabLength()]]

      describe "when multiple lines are selected", ->
        it "outdents selected lines and retains editSession", ->
          editSession.setSelectedBufferRange([[0,1], [3,15]])
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
          expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
          expect(buffer.lineForRow(2)).toBe "  if (items.length <= 1) return items;"
          expect(buffer.lineForRow(3)).toBe "  var pivot = items.shift(), current, left = [], right = [];"
          expect(editSession.getSelectedBufferRange()).toEqual [[0, 1], [3, 15 - editSession.getTabLength()]]

        it "does not outdent the last line of the selection if it ends at column 0", ->
          editSession.setSelectedBufferRange([[0,1], [3,0]])
          editSession.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
          expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
          expect(buffer.lineForRow(2)).toBe "  if (items.length <= 1) return items;"
          expect(buffer.lineForRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

          expect(editSession.getSelectedBufferRange()).toEqual [[0, 1], [3, 0]]

    describe ".toggleLineCommentsInSelection()", ->
      it "toggles comments on the selected lines", ->
        editSession.setSelectedBufferRange([[4, 5], [7, 5]])
        editSession.toggleLineCommentsInSelection()

        expect(buffer.lineForRow(4)).toBe "//     while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "//       current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "//       current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "//     }"
        expect(editSession.getSelectedBufferRange()).toEqual [[4, 8], [7, 8]]

        editSession.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "      current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "    }"

      it "does not comment the last line of a non-empty selection if it ends at column 0", ->
        editSession.setSelectedBufferRange([[4, 5], [7, 0]])
        editSession.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(4)).toBe "//     while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "//       current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "//       current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "    }"

      it "uncomments lines if the first line matches the comment regex", ->
        editSession.setSelectedBufferRange([[4, 5], [4, 5]])
        editSession.toggleLineCommentsInSelection()
        editSession.setSelectedBufferRange([[6, 5], [6, 5]])
        editSession.toggleLineCommentsInSelection()

        expect(buffer.lineForRow(4)).toBe "//     while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "//       current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "    }"

        editSession.setSelectedBufferRange([[4, 5], [7, 5]])
        editSession.toggleLineCommentsInSelection()

        expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "      current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "    }"

      it "preserves selection emptiness", ->
        editSession.setSelectedBufferRange([[4, 0], [4, 0]])
        editSession.toggleLineCommentsInSelection()
        expect(editSession.getSelection().isEmpty()).toBeTruthy()

      it "does not explode if the current language mode has no comment regex", ->
        editSession.destroy()
        editSession = fixturesProject.buildEditSessionForPath(null, autoIndent: false)
        editSession.setSelectedBufferRange([[4, 5], [4, 5]])
        editSession.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"

      it "uncomments when the line lacks the trailing whitespace in the comment regex", ->
        editSession.setSelectedBufferRange([[10, 0], [10, 0]])
        editSession.toggleLineCommentsInSelection()

        expect(buffer.lineForRow(10)).toBe "// "
        expect(editSession.getSelectedBufferRange()).toEqual [[10, 3], [10, 3]]
        editSession.backspace()
        expect(buffer.lineForRow(10)).toBe "//"

        editSession.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(10)).toBe ""
        expect(editSession.getSelectedBufferRange()).toEqual [[10, 0], [10, 0]]

      it "uncomments when the line has leading whitespace", ->
        editSession.setSelectedBufferRange([[10, 0], [10, 0]])
        editSession.toggleLineCommentsInSelection()

        expect(buffer.lineForRow(10)).toBe "// "
        editSession.moveCursorToBeginningOfLine()
        editSession.insertText("  ")
        editSession.setSelectedBufferRange([[10, 0], [10, 0]])
        editSession.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(10)).toBe "  "

    describe ".undo() and .redo()", ->
      it "undoes/redoes the last change", ->
        editSession.insertText("foo")
        editSession.undo()
        expect(buffer.lineForRow(0)).not.toContain "foo"

        editSession.redo()
        expect(buffer.lineForRow(0)).toContain "foo"

      it "batches the undo / redo of changes caused by multiple cursors", ->
        editSession.setCursorScreenPosition([0, 0])
        editSession.addCursorAtScreenPosition([1, 0])

        editSession.insertText("foo")
        editSession.backspace()

        expect(buffer.lineForRow(0)).toContain "fovar"
        expect(buffer.lineForRow(1)).toContain "fo "

        editSession.undo()

        expect(buffer.lineForRow(0)).toContain "foo"
        expect(buffer.lineForRow(1)).toContain "foo"

        editSession.redo()

        expect(buffer.lineForRow(0)).not.toContain "foo"
        expect(buffer.lineForRow(0)).toContain "fovar"

      it "restores the selected ranges after undo and redo", ->
        editSession.setSelectedBufferRanges([[[1, 6], [1, 10]], [[1, 22], [1, 27]]])
        editSession.delete()
        editSession.delete()

        selections = editSession.getSelections()
        expect(buffer.lineForRow(1)).toBe '  var = function( {'

        expect(editSession.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 6]], [[1, 17], [1, 17]]]

        editSession.undo()
        expect(editSession.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 6]], [[1, 18], [1, 18]]]

        editSession.undo()
        expect(editSession.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 10]], [[1, 22], [1, 27]]]

        editSession.redo()
        expect(editSession.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 6]], [[1, 18], [1, 18]]]

      it "restores selected ranges even when the change occurred in another edit session", ->
        otherEditSession = fixturesProject.buildEditSessionForPath(editSession.getPath())
        otherEditSession.setSelectedBufferRange([[2, 2], [3, 3]])
        otherEditSession.delete()

        editSession.undo()

        expect(editSession.getSelectedBufferRange()).toEqual [[2, 2], [3, 3]]
        expect(otherEditSession.getSelectedBufferRange()).toEqual [[3, 3], [3, 3]]

    describe ".transact([fn])", ->
      describe "when called without a function", ->
        it "restores the selection when the transaction is undone/redone", ->
          buffer.setText('1234')
          editSession.setSelectedBufferRange([[0, 1], [0, 3]])
          editSession.transact()

          editSession.delete()
          editSession.moveCursorToEndOfLine()
          editSession.insertText('5')
          expect(buffer.getText()).toBe '145'

          editSession.commit()

          editSession.undo()
          expect(buffer.getText()).toBe '1234'
          expect(editSession.getSelectedBufferRange()).toEqual [[0, 1], [0, 3]]

          editSession.redo()
          expect(buffer.getText()).toBe '145'
          expect(editSession.getSelectedBufferRange()).toEqual [[0, 3], [0, 3]]

    describe "when the buffer is changed (via its direct api, rather than via than edit session)", ->
      it "moves the cursor so it is in the same relative position of the buffer", ->
        expect(editSession.getCursorScreenPosition()).toEqual [0, 0]
        editSession.addCursorAtScreenPosition([0, 5])
        editSession.addCursorAtScreenPosition([1, 0])
        [cursor1, cursor2, cursor3] = editSession.getCursors()

        buffer.insert([0, 1], 'abc')

        expect(cursor1.getScreenPosition()).toEqual [0, 0]
        expect(cursor2.getScreenPosition()).toEqual [0, 8]
        expect(cursor3.getScreenPosition()).toEqual [1, 0]

      it "does not destroy cursor or selection anchors when a change encompasses them", ->
        cursor = editSession.getCursor()
        cursor.setBufferPosition [3, 3]
        editSession.buffer.delete([[3, 1], [3, 5]])
        expect(cursor.getBufferPosition()).toEqual [3, 1]
        expect(editSession.getAnchors().indexOf(cursor.anchor)).not.toBe -1

        selection = editSession.getLastSelection()
        selection.setBufferRange [[3, 5], [3, 10]]
        editSession.buffer.delete [[3, 3], [3, 8]]
        expect(selection.getBufferRange()).toEqual [[3, 3], [3, 5]]
        expect(editSession.getAnchors().indexOf(selection.anchor)).not.toBe -1

      it "merges cursors when the change causes them to overlap", ->
        editSession.setCursorScreenPosition([0, 0])
        editSession.addCursorAtScreenPosition([0, 2])
        editSession.addCursorAtScreenPosition([1, 2])

        [cursor1, cursor2, cursor3] = editSession.getCursors()
        expect(editSession.getCursors().length).toBe 3

        buffer.delete([[0, 0], [0, 2]])

        expect(editSession.getCursors().length).toBe 2
        expect(editSession.getCursors()).toEqual [cursor1, cursor3]
        expect(cursor1.getBufferPosition()).toEqual [0,0]
        expect(cursor3.getBufferPosition()).toEqual [1,2]

  describe "folding", ->
    describe "structural folding", ->
      it "maintains cursor buffer position when a fold is created/destroyed", ->
        editSession.setCursorBufferPosition([5,5])
        editSession.foldAll()
        expect(editSession.getCursorBufferPosition()).toEqual([5,5])

  describe "anchors", ->
    [anchor, destroyHandler] = []

    beforeEach ->
      destroyHandler = jasmine.createSpy("destroyHandler")
      anchor = editSession.addAnchorAtBufferPosition([4, 25])
      anchor.on 'destroyed', destroyHandler

    describe "when a buffer change precedes an anchor", ->
      it "moves the anchor in accordance with the change", ->
        editSession.setSelectedBufferRange([[3, 0], [4, 10]])
        editSession.delete()
        expect(anchor.getBufferPosition()).toEqual [3, 15]
        expect(destroyHandler).not.toHaveBeenCalled()

    describe "when a buffer change surrounds an anchor", ->
      it "destroys the anchor", ->
        editSession.setSelectedBufferRange([[3, 0], [5, 0]])
        editSession.delete()
        expect(destroyHandler).toHaveBeenCalled()
        expect(editSession.getAnchors().indexOf(anchor)).toBe -1

  describe ".clipBufferPosition(bufferPosition)", ->
    it "clips the given position to a valid position", ->
      expect(editSession.clipBufferPosition([-1, -1])).toEqual [0,0]
      expect(editSession.clipBufferPosition([Infinity, Infinity])).toEqual [12,2]
      expect(editSession.clipBufferPosition([8, 57])).toEqual [8, 56]

  describe ".deleteLine()", ->
    it "deletes the first line when the cursor is there", ->
      editSession.getCursor().moveToTop()
      line1 = buffer.lineForRow(1)
      count = buffer.getLineCount()
      expect(buffer.lineForRow(0)).not.toBe(line1)
      editSession.deleteLine()
      expect(buffer.lineForRow(0)).toBe(line1)
      expect(buffer.getLineCount()).toBe(count - 1)

    it "deletes the last line when the cursor is there", ->
      count = buffer.getLineCount()
      secondToLastLine = buffer.lineForRow(count - 2)
      expect(buffer.lineForRow(count - 1)).not.toBe(secondToLastLine)
      editSession.getCursor().moveToBottom()
      editSession.deleteLine()
      newCount = buffer.getLineCount()
      expect(buffer.lineForRow(newCount - 1)).toBe(secondToLastLine)
      expect(newCount).toBe(count - 1)

    it "deletes whole lines when partial lines are selected", ->
      editSession.setSelectedBufferRange([[0, 2], [1, 2]])
      line2 = buffer.lineForRow(2)
      count = buffer.getLineCount()
      expect(buffer.lineForRow(0)).not.toBe(line2)
      expect(buffer.lineForRow(1)).not.toBe(line2)
      editSession.deleteLine()
      expect(buffer.lineForRow(0)).toBe(line2)
      expect(buffer.getLineCount()).toBe(count - 2)

    it "only deletes first line if only newline is selected on second line", ->
      editSession.setSelectedBufferRange([[0, 2], [1, 0]])
      line1 = buffer.lineForRow(1)
      count = buffer.getLineCount()
      expect(buffer.lineForRow(0)).not.toBe(line1)
      editSession.deleteLine()
      expect(buffer.lineForRow(0)).toBe(line1)
      expect(buffer.getLineCount()).toBe(count - 1)

    it "deletes the entire region when invoke on a folded region", ->
      editSession.foldBufferRow(1)
      editSession.getCursor().moveToTop()
      editSession.getCursor().moveDown()
      expect(buffer.getLineCount()).toBe(13)
      editSession.deleteLine()
      expect(buffer.getLineCount()).toBe(4)

    it "deletes the entire file from the bottom up", ->
      count = buffer.getLineCount()
      expect(count).toBeGreaterThan(0)
      for line in [0...count]
        editSession.getCursor().moveToBottom()
        editSession.deleteLine()
      expect(buffer.getLineCount()).toBe(1)
      expect(buffer.getText()).toBe('')

    it "deletes the entire file from the top down", ->
      count = buffer.getLineCount()
      expect(count).toBeGreaterThan(0)
      for line in [0...count]
        editSession.getCursor().moveToTop()
        editSession.deleteLine()
      expect(buffer.getLineCount()).toBe(1)
      expect(buffer.getText()).toBe('')

  describe ".tranpose()", ->
    it "swaps two characters", ->
      editSession.buffer.setText("abc")
      editSession.setCursorScreenPosition([0, 1])
      editSession.transpose()
      expect(editSession.lineForBufferRow(0)).toBe 'bac'

    it "reverses a selection", ->
      editSession.buffer.setText("xabcz")
      editSession.setSelectedBufferRange([[0, 1], [0, 4]])
      editSession.transpose()
      expect(editSession.lineForBufferRow(0)).toBe 'xcbaz'

  describe ".upperCase()", ->
    describe "when there is no selection", ->
      it "upper cases the current word", ->
        editSession.buffer.setText("aBc")
        editSession.setCursorScreenPosition([0, 1])
        editSession.upperCase()
        expect(editSession.lineForBufferRow(0)).toBe 'ABC'
        expect(editSession.getSelectedBufferRange()).toEqual [[0, 1], [0, 1]]

    describe "when there is a selection", ->
      it "upper cases the current selection", ->
        editSession.buffer.setText("abc")
        editSession.setSelectedBufferRange([[0,0], [0,2]])
        editSession.upperCase()
        expect(editSession.lineForBufferRow(0)).toBe 'ABc'
        expect(editSession.getSelectedBufferRange()).toEqual [[0, 0], [0, 2]]

  describe ".lowerCase()", ->
    describe "when there is no selection", ->
      it "lower cases the current word", ->
        editSession.buffer.setText("aBC")
        editSession.setCursorScreenPosition([0, 1])
        editSession.lowerCase()
        expect(editSession.lineForBufferRow(0)).toBe 'abc'
        expect(editSession.getSelectedBufferRange()).toEqual [[0, 1], [0, 1]]

    describe "when there is a selection", ->
      it "lower cases the current selection", ->
        editSession.buffer.setText("ABC")
        editSession.setSelectedBufferRange([[0,0], [0,2]])
        editSession.lowerCase()
        expect(editSession.lineForBufferRow(0)).toBe 'abC'
        expect(editSession.getSelectedBufferRange()).toEqual [[0, 0], [0, 2]]

  describe "soft-tabs detection", ->
    it "assign soft / hard tabs based on the contents of the buffer, or uses the default if unknown", ->
      editSession = fixturesProject.buildEditSessionForPath('sample.js', softTabs: false)
      expect(editSession.softTabs).toBeTruthy()

      editSession = fixturesProject.buildEditSessionForPath('sample-with-tabs.coffee', softTabs: true)
      expect(editSession.softTabs).toBeFalsy()

      editSession = fixturesProject.buildEditSessionForPath(null, softTabs: false)
      expect(editSession.softTabs).toBeFalsy()

  describe ".indentLevelForLine(line)", ->
    it "returns the indent level when the line has only leading whitespace", ->
      expect(editSession.indentLevelForLine("    hello")).toBe(2)
      expect(editSession.indentLevelForLine("   hello")).toBe(1.5)

    it "returns the indent level when the line has only leading tabs", ->
      expect(editSession.indentLevelForLine("\t\thello")).toBe(2)

    it "returns the indent level when the line has mixed leading whitespace and tabs", ->
      expect(editSession.indentLevelForLine("\t  hello")).toBe(2)
      expect(editSession.indentLevelForLine("  \thello")).toBe(2)
      expect(editSession.indentLevelForLine("  \t hello")).toBe(2.5)
      expect(editSession.indentLevelForLine("  \t \thello")).toBe(3.5)

  describe "when the buffer is reloaded", ->
    it "preserves the current cursor position", ->
      editSession.setCursorScreenPosition([0, 1])
      editSession.buffer.reload()
      expect(editSession.getCursorScreenPosition()).toEqual [0,1]

  describe "auto-indent", ->
    describe "editor.autoIndent", ->
      it "auto-indents newlines if editor.autoIndent is true", ->
        config.set("editor.autoIndent", undefined)
        editSession.setCursorBufferPosition([1, 30])
        editSession.insertText("\n")
        expect(editSession.lineForBufferRow(2)).toBe "    "

      it "does not auto-indent newlines if editor.autoIndent is false", ->
        config.set("editor.autoIndent", false)
        editSession.setCursorBufferPosition([1, 30])
        editSession.insertText("\n")
        expect(editSession.lineForBufferRow(2)).toBe ""

      it "auto-indents calls to `indent` if editor.autoIndent is true", ->
        config.set("editor.autoIndent", true)
        editSession.setCursorBufferPosition([1, 30])
        editSession.insertText("\n ")
        expect(editSession.lineForBufferRow(2)).toBe " "
        editSession.indent()
        expect(editSession.lineForBufferRow(2)).toBe "    "

      it "does not auto-indents calls to `indent` if editor.autoIndent is false", ->
        config.set("editor.autoIndent", false)
        editSession.setCursorBufferPosition([1, 30])
        editSession.insertText("\n ")
        expect(editSession.lineForBufferRow(2)).toBe " "
        editSession.indent()
        expect(editSession.lineForBufferRow(2)).toBe "   "

      it "auto-indents selection when autoIndent is called", ->
        editSession.setCursorBufferPosition([2, 0])
        editSession.insertText("    0\n  2\n4\n")

        editSession.setSelectedBufferRange([[2, 0], [4, 0]])
        editSession.autoIndentSelectedRows()

        expect(editSession.lineForBufferRow(2)).toBe "    0"
        expect(editSession.lineForBufferRow(3)).toBe "    2"
        expect(editSession.lineForBufferRow(4)).toBe "4"

    describe "editor.autoIndentOnPaste", ->
      it "does not auto-indent pasted text by default", ->
        editSession.setCursorBufferPosition([2, 0])
        editSession.insertText("0\n  2\n    4\n")
        editSession.getSelection().setBufferRange([[2,0], [5,0]])
        editSession.cutSelectedText()

        editSession.pasteText()
        expect(editSession.lineForBufferRow(2)).toBe "0"
        expect(editSession.lineForBufferRow(3)).toBe "  2"
        expect(editSession.lineForBufferRow(4)).toBe "    4"

      it "auto-indents pasted text when editor.autoIndentOnPaste is true", ->
        config.set("editor.autoIndentOnPaste", true)
        editSession.setCursorBufferPosition([2, 0])
        editSession.insertText("0\n  2\n    4\n")
        editSession.getSelection().setBufferRange([[2,0], [5,0]])
        editSession.cutSelectedText()

        editSession.pasteText()
        expect(editSession.lineForBufferRow(2)).toBe "    0"
        expect(editSession.lineForBufferRow(3)).toBe "      2"
        expect(editSession.lineForBufferRow(4)).toBe "        4"

  describe ".autoDecreaseIndentForRow()", ->
      it "doesn't outdent the first and only row", ->
        editSession.selectAll()
        editSession.insertText("}")
        editSession.autoDecreaseIndentForRow(0)
        expect(editSession.lineForBufferRow(0)).toBe "}"

      it "doesn't outdent a row that is already fully outdented", ->
        editSession.selectAll()
        editSession.insertText("var i;\n}")
        editSession.autoDecreaseIndentForRow(1)
        expect(editSession.lineForBufferRow(1)).toBe "}"
