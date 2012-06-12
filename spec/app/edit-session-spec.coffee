Buffer = require 'buffer'
EditSession = require 'edit-session'

describe "EditSession", ->
  [buffer, editSession, lineLengths] = []

  beforeEach ->
    fakeEditor =
      calcSoftWrapColumn: ->
      tabText: '  '

    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    editSession = new EditSession(editor: fakeEditor, buffer: buffer, autoIndent: false)
    lineLengths = buffer.getLines().map (line) -> line.length

  describe "cursor movement", ->
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

          editSession.setCursorScreenPosition(row: lastLineIndex, column: 1)
          editSession.moveCursorDown()
          expect(editSession.getCursorScreenPosition()).toEqual(row: lastLineIndex, column: lastLine.length)

          editSession.moveCursorUp()
          expect(editSession.getCursorScreenPosition().column).toBe 1

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
        editSession.setCursorScreenPosition([3, 3])
        editSession.moveCursorLeft()
        expect(editSession.getCursorScreenPosition()).toEqual [3, 2]

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

      it "does not throw an exception on an empty line", ->
        editSession.setCursorBufferPosition([10, 0])
        editSession.moveCursorToFirstCharacterOfLine()

    describe ".moveCursorToNextWord()", ->
      it "moves the cursor to the next word or the end of file if there is no next word", ->
        editSession.setCursorBufferPosition [2, 5]
        editSession.addCursorAtBufferPosition [3, 60]
        [cursor1, cursor2] = editSession.getCursors()

        editSession.moveCursorToNextWord()
        expect(cursor1.getBufferPosition()).toEqual [2, 7]
        expect(cursor2.getBufferPosition()).toEqual [4, 4]

        buffer.insert([12, 2], '   ')
        cursor1.setBufferPosition([12, 1])
        editSession.moveCursorToNextWord()
        expect(cursor1.getBufferPosition()).toEqual [12, 5]

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
        editSession.addCursorAtScreenPosition([5, 5])
        editSession.selectToScreenPosition([6, 1])

        selections = editSession.getSelections()
        expect(selections.length).toBe 2
        [selection1, selection2] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 0], [4, 5]]
        expect(selection2.getScreenRange()).toEqual [[5, 5], [6, 1]]

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
      it "inserts a newline below the cursor's current line, autoindents it, and moves the cursor to the end of the line", ->
        editSession.setAutoIndent(true)
        editSession.insertNewlineBelow()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe "  "
        expect(editSession.getCursorBufferPosition()).toEqual [1, 2]

    describe ".backspace()", ->
      describe "when there is a single cursor", ->
        describe "when the cursor is on the middle of the line", ->
          it "removes the character before the cursor", ->
            editSession.setCursorScreenPosition(row: 1, column: 7)
            expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"

            editSession.backspace()

            line = buffer.lineForRow(1)
            expect(line).toBe "  var ort = function(items) {"
            expect(editSession.getCursorScreenPosition()).toEqual {row: 1, column: 6}

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

        describe "when the cursor is at the first column of the first line", ->
          it "does nothing, but doesn't raise an error", ->
            editSession.setCursorScreenPosition(row: 0, column: 0)
            editSession.backspace()

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

      describe "when there are multiple selections", ->
        it "removes all selected text", ->
          editSession.setSelectedBufferRanges([[[0,4], [0,13]], [[0,16], [0,24]]])
          editSession.backspace()
          expect(editSession.lineForBufferRow(0)).toBe 'var  =  () {'

    describe ".backspaceToBeginningOfWord()", ->
      describe "when no text is selected", ->
        it "deletes all text between the cursor and the beginning of the word", ->
          editSession.setCursorBufferPosition([1, 24])
          editSession.addCursorAtBufferPosition([2, 5])
          [cursor1, cursor2] = editSession.getCursors()

          editSession.backspaceToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(ems) {'
          expect(buffer.lineForRow(2)).toBe '    f (items.length <= 1) return items;'
          expect(cursor1.getBufferPosition()).toEqual [1, 22]
          expect(cursor2.getBufferPosition()).toEqual [2, 4]

          editSession.backspaceToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = functionems) f (items.length <= 1) return items;'
          expect(cursor1.getBufferPosition()).toEqual [1, 21]
          expect(cursor2.getBufferPosition()).toEqual [1, 26]

      describe "when text is selected", ->
        it "deletes only selected text", ->
          editSession.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
          editSession.backspaceToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
          expect(buffer.lineForRow(2)).toBe 'if (items.length <= 1) return items;'

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

    describe ".insertTab()", ->
      describe "if 'softTabs' is true (the default)", ->
        it "inserts the value of 'tabText' into the buffer", ->
          tabRegex = new RegExp("^#{editSession.tabText}")
          expect(buffer.lineForRow(0)).not.toMatch(tabRegex)
          editSession.insertTab()
          expect(buffer.lineForRow(0)).toMatch(tabRegex)

      describe "if editSession.softTabs is false", ->
        it "inserts a tab character into the buffer", ->
          editSession.setSoftTabs(false)
          expect(buffer.lineForRow(0)).not.toMatch(/^\t/)
          editSession.insertTab()
          expect(buffer.lineForRow(0)).toMatch(/^\t/)
          expect(editSession.getCursorBufferPosition()).toEqual [0, 1]
          expect(editSession.getCursorScreenPosition()).toEqual [0, editSession.tabText.length]

          editSession.insertTab()
          expect(buffer.lineForRow(0)).toMatch(/^\t\t/)
          expect(editSession.getCursorBufferPosition()).toEqual [0, 2]
          expect(editSession.getCursorScreenPosition()).toEqual [0, editSession.tabText.length * 2]

    describe "pasteboard operations", ->
      pasteboard = null
      beforeEach ->
        pasteboard = 'first'
        spyOn($native, 'writeToPasteboard').andCallFake (text) -> pasteboard = text
        spyOn($native, 'readFromPasteboard').andCallFake -> pasteboard
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
            expect(pasteboard).toBe ' <= 1) return items;\ns.shift(), current, left = [], right = [];'

        describe "when text is selected", ->
          it "only cuts the selected text, not to the end of the line", ->
            editSession.setSelectedBufferRanges([[[2,20], [2, 30]], [[3, 20], [3, 20]]])

            editSession.cutToEndOfLine()

            expect(buffer.lineForRow(2)).toBe '    if (items.lengthurn items;'
            expect(buffer.lineForRow(3)).toBe '    var pivot = item'
            expect(pasteboard).toBe ' <= 1) ret\ns.shift(), current, left = [], right = [];'

      describe ".copySelectedText()", ->
        it "copies selected text onto the clipboard", ->
          editSession.copySelectedText()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
          expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"
          expect($native.readFromPasteboard()).toBe 'quicksort\nsort'

      describe ".pasteText()", ->
        it "pastes text into the buffer", ->
          editSession.pasteText()
          expect(editSession.buffer.lineForRow(0)).toBe "var first = function () {"
          expect(buffer.lineForRow(1)).toBe "  var first = function(items) {"

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
        expect(selections[0].getBufferRange()).toEqual [[1, 6], [1, 6]]
        expect(selections[1].getBufferRange()).toEqual [[1, 17], [1, 17]]

        editSession.undo()
        expect(selections[0].getBufferRange()).toEqual [[1, 6], [1, 6]]
        expect(selections[1].getBufferRange()).toEqual [[1, 18], [1, 18]]

        editSession.undo()
        expect(selections[0].getBufferRange()).toEqual [[1, 6], [1, 10]]
        expect(selections[1].getBufferRange()).toEqual [[1, 22], [1, 27]]

        editSession.redo()
        expect(selections[0].getBufferRange()).toEqual [[1, 6], [1, 6]]
        expect(selections[1].getBufferRange()).toEqual [[1, 18], [1, 18]]

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

      it "merges cursors when the change causes them to overlap", ->
        editSession.setCursorScreenPosition([0, 0])
        editSession.addCursorAtScreenPosition([0, 1])
        editSession.addCursorAtScreenPosition([1, 1])

        [cursor1, cursor2, cursor3] = editSession.getCursors()
        expect(editSession.getCursors().length).toBe 3

        editSession.backspace()
        expect(editSession.getCursors()).toEqual [cursor1, cursor3]
        expect(cursor1.getBufferPosition()).toEqual [0,0]
        expect(cursor3.getBufferPosition()).toEqual [1,0]

        editSession.insertText "x"
        expect(editSession.lineForBufferRow(0)).toBe "xar quicksort = function () {"
        expect(editSession.lineForBufferRow(1)).toBe "x var sort = function(items) {"

