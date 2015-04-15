clipboard = require '../src/safe-clipboard'
TextEditor = require '../src/text-editor'

describe "TextEditor", ->
  [buffer, editor, lineLengths] = []

  convertToHardTabs = (buffer) ->
    buffer.setText(buffer.getText().replace(/[ ]{2}/g, "\t"))

  beforeEach ->
    waitsForPromise ->
      atom.project.open('sample.js', autoIndent: false).then (o) -> editor = o

    runs ->
      buffer = editor.buffer
      lineLengths = buffer.getLines().map (line) -> line.length

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

  describe "when the editor is deserialized", ->
    it "restores selections and folds based on markers in the buffer", ->
      editor.setSelectedBufferRange([[1, 2], [3, 4]])
      editor.addSelectionForBufferRange([[5, 6], [7, 5]], reversed: true)
      editor.foldBufferRow(4)
      expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()

      editor2 = editor.testSerialization()

      expect(editor2.id).toBe editor.id
      expect(editor2.getBuffer().getPath()).toBe editor.getBuffer().getPath()
      expect(editor2.getSelectedBufferRanges()).toEqual [[[1, 2], [3, 4]], [[5, 6], [7, 5]]]
      expect(editor2.getSelections()[1].isReversed()).toBeTruthy()
      expect(editor2.isFoldedAtBufferRow(4)).toBeTruthy()
      editor2.destroy()

    it "preserves the invisibles setting", ->
      atom.config.set('editor.showInvisibles', true)
      previousInvisibles = editor.displayBuffer.invisibles

      editor2 = editor.testSerialization()

      expect(editor2.displayBuffer.invisibles).toEqual previousInvisibles
      expect(editor2.displayBuffer.tokenizedBuffer.invisibles).toEqual previousInvisibles

    it "updates invisibles if the settings have changed between serialization and deserialization", ->
      atom.config.set('editor.showInvisibles', true)
      previousInvisibles = editor.displayBuffer.invisibles

      state = editor.serialize()
      atom.config.set('editor.invisibles', eol: '?')
      editor2 = TextEditor.deserialize(state)

      expect(editor2.displayBuffer.invisibles.eol).toBe '?'
      expect(editor2.displayBuffer.tokenizedBuffer.invisibles.eol).toBe '?'

  describe "when the editor is constructed with an initialLine option", ->
    it "positions the cursor on the specified line", ->
      editor = null

      waitsForPromise ->
        atom.workspace.open('sample.less', initialLine: 5).then (o) -> editor = o

      runs ->
        expect(editor.getLastCursor().getBufferPosition().row).toEqual 5
        expect(editor.getLastCursor().getBufferPosition().column).toEqual 0

  describe "when the editor is constructed with an initialColumn option", ->
    it "positions the cursor on the specified column", ->
      editor = null

      waitsForPromise ->
        atom.workspace.open('sample.less', initialColumn: 8).then (o) -> editor = o

      runs ->
        expect(editor.getLastCursor().getBufferPosition().row).toEqual 0
        expect(editor.getLastCursor().getBufferPosition().column).toEqual 8

  describe "when the editor is reopened with an initialLine option", ->
    it "positions the cursor on the specified line", ->
      editor = null

      waitsForPromise ->
        atom.workspace.open('sample.less', initialLine: 5).then (o) -> editor = o

      waitsForPromise ->
        atom.workspace.open('sample.less', initialLine: 4).then (o) -> editor = o

      runs ->
        expect(editor.getLastCursor().getBufferPosition().row).toEqual 4
        expect(editor.getLastCursor().getBufferPosition().column).toEqual 0

  describe "when the editor is reopened with an initialColumn option", ->
    it "positions the cursor on the specified column", ->
      editor = null

      waitsForPromise ->
        atom.workspace.open('sample.less', initialColumn: 8).then (o) -> editor = o

      waitsForPromise ->
        atom.workspace.open('sample.less', initialColumn: 7).then (o) -> editor = o

      runs ->
        expect(editor.getLastCursor().getBufferPosition().row).toEqual 0
        expect(editor.getLastCursor().getBufferPosition().column).toEqual 7

  describe ".copy()", ->
    it "returns a different edit session with the same initial state", ->
      editor.setSelectedBufferRange([[1, 2], [3, 4]])
      editor.addSelectionForBufferRange([[5, 6], [7, 8]], reversed: true)
      editor.foldBufferRow(4)
      expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()

      editor2 = editor.copy()
      expect(editor2.id).not.toBe editor.id
      expect(editor2.getSelectedBufferRanges()).toEqual editor.getSelectedBufferRanges()
      expect(editor2.getSelections()[1].isReversed()).toBeTruthy()
      expect(editor2.isFoldedAtBufferRow(4)).toBeTruthy()

      # editor2 can now diverge from its origin edit session
      editor2.getLastSelection().setBufferRange([[2, 1], [4, 3]])
      expect(editor2.getSelectedBufferRanges()).not.toEqual editor.getSelectedBufferRanges()
      editor2.unfoldBufferRow(4)
      expect(editor2.isFoldedAtBufferRow(4)).not.toBe editor.isFoldedAtBufferRow(4)

  describe "config defaults", ->
    it "uses the `editor.tabLength`, `editor.softWrap`, and `editor.softTabs`, and `core.fileEncoding` config values", ->
      editor1 = null
      editor2 = null
      atom.config.set('editor.tabLength', 4)
      atom.config.set('editor.softWrap', true)
      atom.config.set('editor.softTabs', false)
      atom.config.set('core.fileEncoding', 'utf16le')

      waitsForPromise ->
        atom.workspace.open('a').then (o) -> editor1 = o

      runs ->
        expect(editor1.getTabLength()).toBe 4
        expect(editor1.isSoftWrapped()).toBe true
        expect(editor1.getSoftTabs()).toBe false
        expect(editor1.getEncoding()).toBe 'utf16le'

        atom.config.set('editor.tabLength', 8)
        atom.config.set('editor.softWrap', false)
        atom.config.set('editor.softTabs', true)
        atom.config.set('core.fileEncoding', 'macroman')

      waitsForPromise ->
        atom.workspace.open('b').then (o) -> editor2 = o

      runs ->
        expect(editor2.getTabLength()).toBe 8
        expect(editor2.isSoftWrapped()).toBe false
        expect(editor2.getSoftTabs()).toBe true
        expect(editor2.getEncoding()).toBe 'macroman'

    it "uses scoped `core.fileEncoding` values", ->
      editor1 = null
      editor2 = null

      atom.config.set('core.fileEncoding', 'utf16le')
      atom.config.set('core.fileEncoding', 'macroman', scopeSelector: '.js')

      waitsForPromise ->
        atom.workspace.open('a').then (o) -> editor1 = o

      runs ->
        expect(editor1.getEncoding()).toBe 'utf16le'

      waitsForPromise ->
        atom.workspace.open('test.js').then (o) -> editor2 = o

      runs ->
        expect(editor2.getEncoding()).toBe 'macroman'

  describe "title", ->
    describe ".getTitle()", ->
      it "uses the basename of the buffer's path as its title, or 'untitled' if the path is undefined", ->
        expect(editor.getTitle()).toBe 'sample.js'
        buffer.setPath(undefined)
        expect(editor.getTitle()).toBe 'untitled'

    describe ".getLongTitle()", ->
      it "appends the name of the containing directory to the basename of the file", ->
        expect(editor.getLongTitle()).toBe 'sample.js - fixtures'
        buffer.setPath(undefined)
        expect(editor.getLongTitle()).toBe 'untitled'

    it "notifies ::onDidChangeTitle observers when the underlying buffer path changes", ->
      observed = []
      editor.onDidChangeTitle (title) -> observed.push(title)

      buffer.setPath('/foo/bar/baz.txt')
      buffer.setPath(undefined)

      expect(observed).toEqual ['baz.txt', 'untitled']

  describe "path", ->
    it "notifies ::onDidChangePath observers when the underlying buffer path changes", ->
      observed = []
      editor.onDidChangePath (filePath) -> observed.push(filePath)

      buffer.setPath(__filename)
      buffer.setPath(undefined)

      expect(observed).toEqual [__filename, undefined]

  describe "encoding", ->
    it "notifies ::onDidChangeEncoding observers when the editor encoding changes", ->
      observed = []
      editor.onDidChangeEncoding (encoding) -> observed.push(encoding)

      editor.setEncoding('utf16le')
      editor.setEncoding('utf16le')
      editor.setEncoding('utf16be')
      editor.setEncoding()
      editor.setEncoding()

      expect(observed).toEqual ['utf16le', 'utf16be', 'utf8']

  describe "cursor", ->
    describe ".getLastCursor()", ->
      it "returns the most recently created cursor", ->
        editor.addCursorAtScreenPosition([1, 0])
        lastCursor = editor.addCursorAtScreenPosition([2, 0])
        expect(editor.getLastCursor()).toBe lastCursor

    describe "when the cursor moves", ->
      it "clears a goal column established by vertical movement", ->
        editor.setText('b')
        editor.setCursorBufferPosition([0,0])
        editor.insertNewline()
        editor.moveUp()
        editor.insertText('a')
        editor.moveDown()
        expect(editor.getCursorBufferPosition()).toEqual [1, 1]

      it "emits an event with the old position, new position, and the cursor that moved", ->
        cursorCallback = jasmine.createSpy('cursor-changed-position')
        editorCallback = jasmine.createSpy('editor-changed-cursor-position')

        editor.getLastCursor().onDidChangePosition(cursorCallback)
        editor.onDidChangeCursorPosition(editorCallback)

        editor.setCursorBufferPosition([2, 4])

        expect(editorCallback).toHaveBeenCalled()
        expect(cursorCallback).toHaveBeenCalled()
        eventObject = editorCallback.mostRecentCall.args[0]
        expect(cursorCallback.mostRecentCall.args[0]).toEqual(eventObject)

        expect(eventObject.oldBufferPosition).toEqual [0, 0]
        expect(eventObject.oldScreenPosition).toEqual [0, 0]
        expect(eventObject.newBufferPosition).toEqual [2, 4]
        expect(eventObject.newScreenPosition).toEqual [2, 4]
        expect(eventObject.cursor).toBe editor.getLastCursor()

    describe ".setCursorScreenPosition(screenPosition)", ->
      it "clears a goal column established by vertical movement", ->
        # set a goal column by moving down
        editor.setCursorScreenPosition(row: 3, column: lineLengths[3])
        editor.moveDown()
        expect(editor.getCursorScreenPosition().column).not.toBe 6

        # clear the goal column by explicitly setting the cursor position
        editor.setCursorScreenPosition([4,6])
        expect(editor.getCursorScreenPosition().column).toBe 6

        editor.moveDown()
        expect(editor.getCursorScreenPosition().column).toBe 6

      it "merges multiple cursors", ->
        editor.setCursorScreenPosition([0, 0])
        editor.addCursorAtScreenPosition([0, 1])
        [cursor1, cursor2] = editor.getCursors()
        editor.setCursorScreenPosition([4, 7])
        expect(editor.getCursors().length).toBe 1
        expect(editor.getCursors()).toEqual [cursor1]
        expect(editor.getCursorScreenPosition()).toEqual [4, 7]

      describe "when soft-wrap is enabled and code is folded", ->
        beforeEach ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          editor.createFold(2, 3)

        it "positions the cursor at the buffer position that corresponds to the given screen position", ->
          editor.setCursorScreenPosition([9, 0])
          expect(editor.getCursorBufferPosition()).toEqual [8, 10]

    describe ".moveUp()", ->
      it "moves the cursor up", ->
        editor.setCursorScreenPosition([2, 2])
        editor.moveUp()
        expect(editor.getCursorScreenPosition()).toEqual [1, 2]

      it "retains the goal column across lines of differing length", ->
        expect(lineLengths[6]).toBeGreaterThan(32)
        editor.setCursorScreenPosition(row: 6, column: 32)

        editor.moveUp()
        expect(editor.getCursorScreenPosition().column).toBe lineLengths[5]

        editor.moveUp()
        expect(editor.getCursorScreenPosition().column).toBe lineLengths[4]

        editor.moveUp()
        expect(editor.getCursorScreenPosition().column).toBe 32

      describe "when the cursor is on the first line", ->
        it "moves the cursor to the beginning of the line, but retains the goal column", ->
          editor.setCursorScreenPosition([0, 4])
          editor.moveUp()
          expect(editor.getCursorScreenPosition()).toEqual([0, 0])

          editor.moveDown()
          expect(editor.getCursorScreenPosition()).toEqual([1, 4])

      describe "when there is a selection", ->
        beforeEach ->
          editor.setSelectedBufferRange([[4, 9],[5, 10]])

        it "moves above the selection", ->
          cursor = editor.getLastCursor()
          editor.moveUp()
          expect(cursor.getBufferPosition()).toEqual [3, 9]

      it "merges cursors when they overlap", ->
        editor.addCursorAtScreenPosition([1, 0])
        [cursor1, cursor2] = editor.getCursors()

        editor.moveUp()
        expect(editor.getCursors()).toEqual [cursor1]
        expect(cursor1.getBufferPosition()).toEqual [0,0]

      describe "when the cursor was moved down from the beginning of an indented soft-wrapped line", ->
        it "moves to the beginning of the previous line", ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)

          editor.setCursorScreenPosition([3, 0])
          editor.moveDown()
          editor.moveDown()
          editor.moveUp()
          expect(editor.getCursorScreenPosition()).toEqual [4, 4]

    describe ".moveDown()", ->
      it "moves the cursor down", ->
        editor.setCursorScreenPosition([2, 2])
        editor.moveDown()
        expect(editor.getCursorScreenPosition()).toEqual [3, 2]

      it "retains the goal column across lines of differing length", ->
        editor.setCursorScreenPosition(row: 3, column: lineLengths[3])

        editor.moveDown()
        expect(editor.getCursorScreenPosition().column).toBe lineLengths[4]

        editor.moveDown()
        expect(editor.getCursorScreenPosition().column).toBe lineLengths[5]

        editor.moveDown()
        expect(editor.getCursorScreenPosition().column).toBe lineLengths[3]

      describe "when the cursor is on the last line", ->
        it "moves the cursor to the end of line, but retains the goal column when moving back up", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.lineForRow(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setCursorScreenPosition(row: lastLineIndex, column: editor.getTabLength())
          editor.moveDown()
          expect(editor.getCursorScreenPosition()).toEqual(row: lastLineIndex, column: lastLine.length)

          editor.moveUp()
          expect(editor.getCursorScreenPosition().column).toBe editor.getTabLength()

        it "retains a goal column of 0 when moving back up", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.lineForRow(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          editor.setCursorScreenPosition(row: lastLineIndex, column: 0)
          editor.moveDown()
          editor.moveUp()
          expect(editor.getCursorScreenPosition().column).toBe 0

      describe "when the cursor is at the beginning of an indented soft-wrapped line", ->
        it "moves to the beginning of the line's continuation on the next screen row", ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)

          editor.setCursorScreenPosition([3, 0])
          editor.moveDown()
          expect(editor.getCursorScreenPosition()).toEqual [4, 4]


      describe "when there is a selection", ->
        beforeEach ->
          editor.setSelectedBufferRange([[4, 9],[5, 10]])

        it "moves below the selection", ->
          cursor = editor.getLastCursor()
          editor.moveDown()
          expect(cursor.getBufferPosition()).toEqual [6, 10]

      it "merges cursors when they overlap", ->
        editor.setCursorScreenPosition([12, 2])
        editor.addCursorAtScreenPosition([11, 2])
        [cursor1, cursor2] = editor.getCursors()

        editor.moveDown()
        expect(editor.getCursors()).toEqual [cursor1]
        expect(cursor1.getBufferPosition()).toEqual [12,2]

    describe ".moveLeft()", ->
      it "moves the cursor by one column to the left", ->
        editor.setCursorScreenPosition([1, 8])
        editor.moveLeft()
        expect(editor.getCursorScreenPosition()).toEqual [1, 7]

      it "moves the cursor by n columns to the left", ->
        editor.setCursorScreenPosition([1, 8])
        editor.moveLeft(4)
        expect(editor.getCursorScreenPosition()).toEqual [1, 4]

      it "moves the cursor by two rows up when the columnCount is longer than an entire line", ->
        editor.setCursorScreenPosition([2, 2])
        editor.moveLeft(34)
        expect(editor.getCursorScreenPosition()).toEqual [0, 29]

      it "moves the cursor to the beginning columnCount is longer than the position in the buffer", ->
        editor.setCursorScreenPosition([1, 0])
        editor.moveLeft(100)
        expect(editor.getCursorScreenPosition()).toEqual [0, 0]

      describe "when the cursor is in the first column", ->
        describe "when there is a previous line", ->
          it "wraps to the end of the previous line", ->
            editor.setCursorScreenPosition(row: 1, column: 0)
            editor.moveLeft()
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: buffer.lineForRow(0).length)

          it "moves the cursor by one row up and n columns to the left", ->
            editor.setCursorScreenPosition([1, 0])
            editor.moveLeft(4)
            expect(editor.getCursorScreenPosition()).toEqual [0, 26]

        describe "when the next line is empty", ->
          it "wraps to the beginning of the previous line", ->
            editor.setCursorScreenPosition([11, 0])
            editor.moveLeft()
            expect(editor.getCursorScreenPosition()).toEqual [10, 0]

        describe "when line is wrapped and follow previous line indentation", ->
          beforeEach ->
            editor.setSoftWrapped(true)
            editor.setEditorWidthInChars(50)

          it "wraps to the end of the previous line", ->
            editor.setCursorScreenPosition([4, 4])
            editor.moveLeft()
            expect(editor.getCursorScreenPosition()).toEqual [3, 50]

        describe "when the cursor is on the first line", ->
          it "remains in the same position (0,0)", ->
            editor.setCursorScreenPosition(row: 0, column: 0)
            editor.moveLeft()
            expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

          it "remains in the same position (0,0) when columnCount is specified", ->
            editor.setCursorScreenPosition([0, 0])
            editor.moveLeft(4)
            expect(editor.getCursorScreenPosition()).toEqual [0, 0]

      describe "when softTabs is enabled and the cursor is preceded by leading whitespace", ->
        it "skips tabLength worth of whitespace at a time", ->
          editor.setCursorBufferPosition([5, 6])

          editor.moveLeft()
          expect(editor.getCursorBufferPosition()).toEqual [5, 4]

      describe "when there is a selection", ->
        beforeEach ->
          editor.setSelectedBufferRange([[5, 22],[5, 27]])

        it "moves to the left of the selection", ->
          cursor = editor.getLastCursor()
          editor.moveLeft()
          expect(cursor.getBufferPosition()).toEqual [5, 22]

          editor.moveLeft()
          expect(cursor.getBufferPosition()).toEqual [5, 21]

      it "merges cursors when they overlap", ->
        editor.setCursorScreenPosition([0, 0])
        editor.addCursorAtScreenPosition([0, 1])

        [cursor1, cursor2] = editor.getCursors()
        editor.moveLeft()
        expect(editor.getCursors()).toEqual [cursor1]
        expect(cursor1.getBufferPosition()).toEqual [0,0]

    describe ".moveRight()", ->
      it "moves the cursor by one column to the right", ->
        editor.setCursorScreenPosition([3, 3])
        editor.moveRight()
        expect(editor.getCursorScreenPosition()).toEqual [3, 4]

      it "moves the cursor by n columns to the right", ->
        editor.setCursorScreenPosition([3, 7])
        editor.moveRight(4)
        expect(editor.getCursorScreenPosition()).toEqual [3, 11]

      it "moves the cursor by two rows down when the columnCount is longer than an entire line", ->
        editor.setCursorScreenPosition([0, 29])
        editor.moveRight(34)
        expect(editor.getCursorScreenPosition()).toEqual [2, 2]

      it "moves the cursor to the end of the buffer when columnCount is longer than the number of characters following the cursor position", ->
        editor.setCursorScreenPosition([11, 5])
        editor.moveRight(100)
        expect(editor.getCursorScreenPosition()).toEqual [12, 2]

      describe "when the cursor is on the last column of a line", ->
        describe "when there is a subsequent line", ->
          it "wraps to the beginning of the next line", ->
            editor.setCursorScreenPosition([0, buffer.lineForRow(0).length])
            editor.moveRight()
            expect(editor.getCursorScreenPosition()).toEqual [1, 0]

          it "moves the cursor by one row down and n columns to the right", ->
            editor.setCursorScreenPosition([0, buffer.lineForRow(0).length])
            editor.moveRight(4)
            expect(editor.getCursorScreenPosition()).toEqual [1, 3]

        describe "when the next line is empty", ->
          it "wraps to the beginning of the next line", ->
            editor.setCursorScreenPosition([9, 4])
            editor.moveRight()
            expect(editor.getCursorScreenPosition()).toEqual [10, 0]

        describe "when the cursor is on the last line", ->
          it "remains in the same position", ->
            lastLineIndex = buffer.getLines().length - 1
            lastLine = buffer.lineForRow(lastLineIndex)
            expect(lastLine.length).toBeGreaterThan(0)

            lastPosition = {row: lastLineIndex, column: lastLine.length}
            editor.setCursorScreenPosition(lastPosition)
            editor.moveRight()

            expect(editor.getCursorScreenPosition()).toEqual(lastPosition)

      describe "when there is a selection", ->
        beforeEach ->
          editor.setSelectedBufferRange([[5, 22],[5, 27]])

        it "moves to the left of the selection", ->
          cursor = editor.getLastCursor()
          editor.moveRight()
          expect(cursor.getBufferPosition()).toEqual [5, 27]

          editor.moveRight()
          expect(cursor.getBufferPosition()).toEqual [5, 28]

      it "merges cursors when they overlap", ->
        editor.setCursorScreenPosition([12, 2])
        editor.addCursorAtScreenPosition([12, 1])
        [cursor1, cursor2] = editor.getCursors()

        editor.moveRight()
        expect(editor.getCursors()).toEqual [cursor1]
        expect(cursor1.getBufferPosition()).toEqual [12,2]

    describe ".moveToTop()", ->
      it "moves the cursor to the top of the buffer", ->
        editor.setCursorScreenPosition [11,1]
        editor.addCursorAtScreenPosition [12,0]
        editor.moveToTop()
        expect(editor.getCursors().length).toBe 1
        expect(editor.getCursorBufferPosition()).toEqual [0,0]

    describe ".moveToBottom()", ->
      it "moves the cusor to the bottom of the buffer", ->
        editor.setCursorScreenPosition [0,0]
        editor.addCursorAtScreenPosition [1,0]
        editor.moveToBottom()
        expect(editor.getCursors().length).toBe 1
        expect(editor.getCursorBufferPosition()).toEqual [12,2]

    describe ".moveToBeginningOfScreenLine()", ->
      describe "when soft wrap is on", ->
        it "moves cursor to the beginning of the screen line", ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(10)
          editor.setCursorScreenPosition([1, 2])
          editor.moveToBeginningOfScreenLine()
          cursor = editor.getLastCursor()
          expect(cursor.getScreenPosition()).toEqual [1, 0]

      describe "when soft wrap is off", ->
        it "moves cursor to the beginning of then line", ->
          editor.setCursorScreenPosition [0,5]
          editor.addCursorAtScreenPosition [1,7]
          editor.moveToBeginningOfScreenLine()
          expect(editor.getCursors().length).toBe 2
          [cursor1, cursor2] = editor.getCursors()
          expect(cursor1.getBufferPosition()).toEqual [0,0]
          expect(cursor2.getBufferPosition()).toEqual [1,0]

    describe ".moveToEndOfScreenLine()", ->
      describe "when soft wrap is on", ->
        it "moves cursor to the beginning of the screen line", ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(10)
          editor.setCursorScreenPosition([1, 2])
          editor.moveToEndOfScreenLine()
          cursor = editor.getLastCursor()
          expect(cursor.getScreenPosition()).toEqual [1, 9]

      describe "when soft wrap is off", ->
        it "moves cursor to the end of line", ->
          editor.setCursorScreenPosition [0,0]
          editor.addCursorAtScreenPosition [1,0]
          editor.moveToEndOfScreenLine()
          expect(editor.getCursors().length).toBe 2
          [cursor1, cursor2] = editor.getCursors()
          expect(cursor1.getBufferPosition()).toEqual [0,29]
          expect(cursor2.getBufferPosition()).toEqual [1,30]

    describe ".moveToBeginningOfLine()", ->
      it "moves cursor to the beginning of the buffer line", ->
        editor.setSoftWrapped(true)
        editor.setEditorWidthInChars(10)
        editor.setCursorScreenPosition([1, 2])
        editor.moveToBeginningOfLine()
        cursor = editor.getLastCursor()
        expect(cursor.getScreenPosition()).toEqual [0, 0]

    describe ".moveToEndOfLine()", ->
      it "moves cursor to the end of the buffer line", ->
        editor.setSoftWrapped(true)
        editor.setEditorWidthInChars(10)
        editor.setCursorScreenPosition([0, 2])
        editor.moveToEndOfLine()
        cursor = editor.getLastCursor()
        expect(cursor.getScreenPosition()).toEqual [3, 4]

    describe ".moveToFirstCharacterOfLine()", ->
      describe "when soft wrap is on", ->
        it "moves to the first character of the current screen line or the beginning of the screen line if it's already on the first character", ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(10)
          editor.setCursorScreenPosition [2,5]
          editor.addCursorAtScreenPosition [8,7]

          editor.moveToFirstCharacterOfLine()
          [cursor1, cursor2] = editor.getCursors()
          expect(cursor1.getScreenPosition()).toEqual [2,0]
          expect(cursor2.getScreenPosition()).toEqual [8,2]

          editor.moveToFirstCharacterOfLine()
          expect(cursor1.getScreenPosition()).toEqual [2,0]
          expect(cursor2.getScreenPosition()).toEqual [8,2]

      describe "when soft wrap is off", ->
        it "moves to the first character of the current line or the beginning of the line if it's already on the first character", ->
          editor.setCursorScreenPosition [0,5]
          editor.addCursorAtScreenPosition [1,7]

          editor.moveToFirstCharacterOfLine()
          [cursor1, cursor2] = editor.getCursors()
          expect(cursor1.getBufferPosition()).toEqual [0,0]
          expect(cursor2.getBufferPosition()).toEqual [1,2]

          editor.moveToFirstCharacterOfLine()
          expect(cursor1.getBufferPosition()).toEqual [0,0]
          expect(cursor2.getBufferPosition()).toEqual [1,0]

        it "moves to the beginning of the line if it only contains whitespace ", ->
          editor.setText("first\n    \nthird")
          editor.setCursorScreenPosition [1,2]
          editor.moveToFirstCharacterOfLine()
          cursor = editor.getLastCursor()
          expect(cursor.getBufferPosition()).toEqual [1,0]

        describe "when invisible characters are enabled with soft tabs", ->
          it "moves to the first character of the current line without being confused by the invisible characters", ->
            atom.config.set('editor.showInvisibles', true)
            editor.setCursorScreenPosition [1,7]
            editor.moveToFirstCharacterOfLine()
            expect(editor.getCursorBufferPosition()).toEqual [1,2]
            editor.moveToFirstCharacterOfLine()
            expect(editor.getCursorBufferPosition()).toEqual [1,0]

        describe "when invisible characters are enabled with hard tabs", ->
          it "moves to the first character of the current line without being confused by the invisible characters", ->
            atom.config.set('editor.showInvisibles', true)
            buffer.setTextInRange([[1, 0], [1, Infinity]], '\t\t\ta', normalizeLineEndings: false)

            editor.setCursorScreenPosition [1,7]
            editor.moveToFirstCharacterOfLine()
            expect(editor.getCursorBufferPosition()).toEqual [1,3]
            editor.moveToFirstCharacterOfLine()
            expect(editor.getCursorBufferPosition()).toEqual [1,0]

    describe ".moveToBeginningOfWord()", ->
      it "moves the cursor to the beginning of the word", ->
        editor.setCursorBufferPosition [0, 8]
        editor.addCursorAtBufferPosition [1, 12]
        editor.addCursorAtBufferPosition [3, 0]
        [cursor1, cursor2, cursor3] = editor.getCursors()

        editor.moveToBeginningOfWord()

        expect(cursor1.getBufferPosition()).toEqual [0, 4]
        expect(cursor2.getBufferPosition()).toEqual [1, 11]
        expect(cursor3.getBufferPosition()).toEqual [2, 39]

      it "does not fail at position [0, 0]", ->
        editor.setCursorBufferPosition([0, 0])
        editor.moveToBeginningOfWord()

      it "treats lines with only whitespace as a word", ->
        editor.setCursorBufferPosition([11, 0])
        editor.moveToBeginningOfWord()
        expect(editor.getCursorBufferPosition()).toEqual [10, 0]

      it "works when the current line is blank", ->
        editor.setCursorBufferPosition([10, 0])
        editor.moveToBeginningOfWord()
        expect(editor.getCursorBufferPosition()).toEqual [9, 2]

    describe ".moveToPreviousWordBoundary()", ->
      it "moves the cursor to the previous word boundary", ->
        editor.setCursorBufferPosition [0, 8]
        editor.addCursorAtBufferPosition [2, 0]
        editor.addCursorAtBufferPosition [2, 4]
        editor.addCursorAtBufferPosition [3, 14]
        [cursor1, cursor2, cursor3, cursor4] = editor.getCursors()

        editor.moveToPreviousWordBoundary()

        expect(cursor1.getBufferPosition()).toEqual [0, 4]
        expect(cursor2.getBufferPosition()).toEqual [1, 30]
        expect(cursor3.getBufferPosition()).toEqual [2, 0]
        expect(cursor4.getBufferPosition()).toEqual [3, 13]

    describe ".moveToNextWordBoundary()", ->
      it "moves the cursor to the previous word boundary", ->
        editor.setCursorBufferPosition [0, 8]
        editor.addCursorAtBufferPosition [2, 40]
        editor.addCursorAtBufferPosition [3, 0]
        editor.addCursorAtBufferPosition [3, 30]
        [cursor1, cursor2, cursor3, cursor4] = editor.getCursors()

        editor.moveToNextWordBoundary()

        expect(cursor1.getBufferPosition()).toEqual [0, 13]
        expect(cursor2.getBufferPosition()).toEqual [3, 0]
        expect(cursor3.getBufferPosition()).toEqual [3, 4]
        expect(cursor4.getBufferPosition()).toEqual [3, 31]

    describe ".moveToEndOfWord()", ->
      it "moves the cursor to the end of the word", ->
        editor.setCursorBufferPosition [0, 6]
        editor.addCursorAtBufferPosition [1, 10]
        editor.addCursorAtBufferPosition [2, 40]
        [cursor1, cursor2, cursor3] = editor.getCursors()

        editor.moveToEndOfWord()

        expect(cursor1.getBufferPosition()).toEqual [0, 13]
        expect(cursor2.getBufferPosition()).toEqual [1, 12]
        expect(cursor3.getBufferPosition()).toEqual [3, 7]

      it "does not blow up when there is no next word", ->
        editor.setCursorBufferPosition [Infinity, Infinity]
        endPosition = editor.getCursorBufferPosition()
        editor.moveToEndOfWord()
        expect(editor.getCursorBufferPosition()).toEqual endPosition

      it "treats lines with only whitespace as a word", ->
        editor.setCursorBufferPosition([9, 4])
        editor.moveToEndOfWord()
        expect(editor.getCursorBufferPosition()).toEqual [10, 0]

      it "works when the current line is blank", ->
        editor.setCursorBufferPosition([10, 0])
        editor.moveToEndOfWord()
        expect(editor.getCursorBufferPosition()).toEqual [11, 8]

    describe ".moveToBeginningOfNextWord()", ->
      it "moves the cursor before the first character of the next word", ->
        editor.setCursorBufferPosition [0,6]
        editor.addCursorAtBufferPosition [1,11]
        editor.addCursorAtBufferPosition [2,0]
        [cursor1, cursor2, cursor3] = editor.getCursors()

        editor.moveToBeginningOfNextWord()

        expect(cursor1.getBufferPosition()).toEqual [0, 14]
        expect(cursor2.getBufferPosition()).toEqual [1, 13]
        expect(cursor3.getBufferPosition()).toEqual [2, 4]

        # When the cursor is on whitespace
        editor.setText("ab cde- ")
        editor.setCursorBufferPosition [0,2]
        cursor = editor.getLastCursor()
        editor.moveToBeginningOfNextWord()

        expect(cursor.getBufferPosition()).toEqual [0, 3]

      it "does not blow up when there is no next word", ->
        editor.setCursorBufferPosition [Infinity, Infinity]
        endPosition = editor.getCursorBufferPosition()
        editor.moveToBeginningOfNextWord()
        expect(editor.getCursorBufferPosition()).toEqual endPosition

      it "treats lines with only whitespace as a word", ->
        editor.setCursorBufferPosition([9, 4])
        editor.moveToBeginningOfNextWord()
        expect(editor.getCursorBufferPosition()).toEqual [10, 0]

      it "works when the current line is blank", ->
        editor.setCursorBufferPosition([10, 0])
        editor.moveToBeginningOfNextWord()
        expect(editor.getCursorBufferPosition()).toEqual [11, 9]

    describe ".moveToBeginningOfNextParagraph()", ->
      it "moves the cursor before the first line of the next paragraph", ->
        editor.setCursorBufferPosition [0, 6]
        editor.foldBufferRow(4)

        editor.moveToBeginningOfNextParagraph()
        expect(editor.getCursorBufferPosition()).toEqual  [10, 0]

        editor.setText("")
        editor.setCursorBufferPosition [0, 0]
        editor.moveToBeginningOfNextParagraph()
        expect(editor.getCursorBufferPosition()).toEqual [0, 0]

    describe ".moveToBeginningOfPreviousParagraph()", ->
      it "moves the cursor before the first line of the pevious paragraph", ->
        editor.setCursorBufferPosition [10, 0]
        editor.foldBufferRow(4)

        editor.moveToBeginningOfPreviousParagraph()
        expect(editor.getCursorBufferPosition()).toEqual [0, 0]

        editor.setText("")
        editor.setCursorBufferPosition [0, 0]
        editor.moveToBeginningOfPreviousParagraph()
        expect(editor.getCursorBufferPosition()).toEqual [0, 0]

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
        editor.setCursorBufferPosition([1, 7])
        expect(editor.getCurrentParagraphBufferRange()).toEqual [[0, 0], [2, 8]]

        editor.setCursorBufferPosition([7, 1])
        expect(editor.getCurrentParagraphBufferRange()).toEqual [[5, 0], [7, 3]]

        editor.setCursorBufferPosition([9, 10])
        expect(editor.getCurrentParagraphBufferRange()).toEqual [[9, 0], [10, 32]]

        # between paragraphs
        editor.setCursorBufferPosition([3, 1])
        expect(editor.getCurrentParagraphBufferRange()).toBeUndefined()

    describe "::getCursorScreenPositions()", ->
      it "returns the cursor positions in the order they were added", ->
        editor.foldBufferRow(4)
        cursor1 = editor.addCursorAtBufferPosition([8, 5])
        cursor2 = editor.addCursorAtBufferPosition([3, 5])
        expect(editor.getCursorScreenPositions()).toEqual [[0, 0], [5, 5], [3, 5]]

    describe "::getCursorsOrderedByBufferPosition()", ->
      it "returns all cursors ordered by buffer positions", ->
        originalCursor = editor.getLastCursor()
        cursor1 = editor.addCursorAtBufferPosition([8, 5])
        cursor2 = editor.addCursorAtBufferPosition([4, 5])
        expect(editor.getCursorsOrderedByBufferPosition()).toEqual [originalCursor, cursor2, cursor1]

    describe "addCursorAtScreenPosition(screenPosition)", ->
      describe "when a cursor already exists at the position", ->
        it "returns the existing cursor", ->
          cursor1 = editor.addCursorAtScreenPosition([0,2])
          cursor2 = editor.addCursorAtScreenPosition([0,2])
          expect(cursor2.marker).toBe cursor1.marker

    describe "addCursorAtBufferPosition(bufferPosition)", ->
      describe "when a cursor already exists at the position", ->
        it "returns the existing cursor", ->
          cursor1 = editor.addCursorAtBufferPosition([1,4])
          cursor2 = editor.addCursorAtBufferPosition([1,4])
          expect(cursor2.marker).toBe cursor1.marker

    describe "autoscroll", ->
      beforeEach ->
        editor.setVerticalScrollMargin(2)
        editor.setHorizontalScrollMargin(2)
        editor.setLineHeightInPixels(10)
        editor.setDefaultCharWidth(10)
        editor.setHorizontalScrollbarHeight(0)
        editor.setHeight(5.5 * 10)
        editor.setWidth(5.5 * 10)

      it "scrolls down when the last cursor gets closer than ::verticalScrollMargin to the bottom of the editor", ->
        expect(editor.getScrollTop()).toBe 0
        expect(editor.getScrollBottom()).toBe 5.5 * 10

        editor.setCursorScreenPosition([2, 0])
        expect(editor.getScrollBottom()).toBe 5.5 * 10

        editor.moveDown()
        expect(editor.getScrollBottom()).toBe 6 * 10

        editor.moveDown()
        expect(editor.getScrollBottom()).toBe 7 * 10

      it "scrolls up when the last cursor gets closer than ::verticalScrollMargin to the top of the editor", ->
        editor.setCursorScreenPosition([11, 0])
        editor.setScrollBottom(editor.getScrollHeight())

        editor.moveUp()
        expect(editor.getScrollBottom()).toBe editor.getScrollHeight()

        editor.moveUp()
        expect(editor.getScrollTop()).toBe 7 * 10

        editor.moveUp()
        expect(editor.getScrollTop()).toBe 6 * 10

      it "scrolls right when the last cursor gets closer than ::horizontalScrollMargin to the right of the editor", ->
        expect(editor.getScrollLeft()).toBe 0
        expect(editor.getScrollRight()).toBe 5.5 * 10

        editor.setCursorScreenPosition([0, 2])
        expect(editor.getScrollRight()).toBe 5.5 * 10

        editor.moveRight()
        expect(editor.getScrollRight()).toBe 6 * 10

        editor.moveRight()
        expect(editor.getScrollRight()).toBe 7 * 10

      it "scrolls left when the last cursor gets closer than ::horizontalScrollMargin to the left of the editor", ->
        editor.setScrollRight(editor.getScrollWidth())
        expect(editor.getScrollRight()).toBe editor.getScrollWidth()
        editor.setCursorScreenPosition([6, 62], autoscroll: false)

        editor.moveLeft()
        expect(editor.getScrollLeft()).toBe 59 * 10

        editor.moveLeft()
        expect(editor.getScrollLeft()).toBe 58 * 10

      it "scrolls down when inserting lines makes the document longer than the editor's height", ->
        editor.setCursorScreenPosition([13, Infinity])
        editor.insertNewline()
        expect(editor.getScrollBottom()).toBe 14 * 10
        editor.insertNewline()
        expect(editor.getScrollBottom()).toBe 15 * 10

      it "autoscrolls to the cursor when it moves due to undo", ->
        editor.insertText('abc')
        editor.setScrollTop(Infinity)
        editor.undo()
        expect(editor.getScrollTop()).toBe 0

      it "doesn't scroll when the cursor moves into the visible area", ->
        editor.setCursorBufferPosition([0, 0])
        editor.setScrollTop(40)
        expect(editor.getVisibleRowRange()).toEqual([4, 9])
        editor.setCursorBufferPosition([6, 0])
        expect(editor.getScrollTop()).toBe 40

      it "honors the autoscroll option on cursor and selection manipulation methods", ->
        expect(editor.getScrollTop()).toBe 0
        editor.addCursorAtScreenPosition([11, 11], autoscroll: false)
        expect(editor.getScrollTop()).toBe 0
        editor.addCursorAtBufferPosition([11, 11], autoscroll: false)
        expect(editor.getScrollTop()).toBe 0
        editor.setCursorScreenPosition([11, 11], autoscroll: false)
        expect(editor.getScrollTop()).toBe 0
        editor.setCursorBufferPosition([11, 11], autoscroll: false)
        expect(editor.getScrollTop()).toBe 0
        editor.addSelectionForBufferRange([[11, 11], [11, 11]], autoscroll: false)
        expect(editor.getScrollTop()).toBe 0
        editor.addSelectionForScreenRange([[11, 11], [11, 12]], autoscroll: false)
        expect(editor.getScrollTop()).toBe 0
        editor.setSelectedBufferRange([[11, 0], [11, 1]], autoscroll: false)
        expect(editor.getScrollTop()).toBe 0
        editor.setSelectedScreenRange([[11, 0], [11, 6]], autoscroll: false)
        expect(editor.getScrollTop()).toBe 0
        editor.clearSelections(autoscroll: false)
        expect(editor.getScrollTop()).toBe 0

        editor.addSelectionForScreenRange([[0, 0], [0, 4]])

        editor.getCursors()[0].setScreenPosition([11, 11], autoscroll: true)
        expect(editor.getScrollTop()).toBeGreaterThan 0
        editor.getCursors()[0].setBufferPosition([0, 0], autoscroll: true)
        expect(editor.getScrollTop()).toBe 0
        editor.getSelections()[0].setScreenRange([[11, 0], [11, 4]], autoscroll: true)
        expect(editor.getScrollTop()).toBeGreaterThan 0
        editor.getSelections()[0].setBufferRange([[0, 0], [0, 4]], autoscroll: true)
        expect(editor.getScrollTop()).toBe 0

    describe '.logCursorScope()', ->
      beforeEach ->
        spyOn(atom.notifications, 'addInfo')

      it 'opens a notification', ->
        editor.logCursorScope()

        expect(atom.notifications.addInfo).toHaveBeenCalled()

  describe "selection", ->
    selection = null

    beforeEach ->
      selection = editor.getLastSelection()

    describe "when the selection range changes", ->
      it "emits an event with the old range, new range, and the selection that moved", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])

        editor.onDidChangeSelectionRange rangeChangedHandler = jasmine.createSpy()
        editor.selectToBufferPosition([6, 2])

        expect(rangeChangedHandler).toHaveBeenCalled()
        eventObject = rangeChangedHandler.mostRecentCall.args[0]

        expect(eventObject.oldBufferRange).toEqual [[3, 0], [4, 5]]
        expect(eventObject.oldScreenRange).toEqual [[3, 0], [4, 5]]
        expect(eventObject.newBufferRange).toEqual [[3, 0], [6, 2]]
        expect(eventObject.newScreenRange).toEqual [[3, 0], [6, 2]]
        expect(eventObject.selection).toBe selection

    describe ".selectUp/Down/Left/Right()", ->
      it "expands each selection to its cursor's new location", ->
        editor.setSelectedBufferRanges([[[0,9], [0,13]], [[3,16], [3,21]]])
        [selection1, selection2] = editor.getSelections()

        editor.selectRight()
        expect(selection1.getBufferRange()).toEqual [[0,9], [0,14]]
        expect(selection2.getBufferRange()).toEqual [[3,16], [3,22]]

        editor.selectLeft()
        editor.selectLeft()
        expect(selection1.getBufferRange()).toEqual [[0,9], [0,12]]
        expect(selection2.getBufferRange()).toEqual [[3,16], [3,20]]

        editor.selectDown()
        expect(selection1.getBufferRange()).toEqual [[0,9], [1,12]]
        expect(selection2.getBufferRange()).toEqual [[3,16], [4,20]]

        editor.selectUp()
        expect(selection1.getBufferRange()).toEqual [[0,9], [0,12]]
        expect(selection2.getBufferRange()).toEqual [[3,16], [3,20]]

      it "merges selections when they intersect when moving down", ->
        editor.setSelectedBufferRanges([[[0,9], [0,13]], [[1,10], [1,20]], [[2,15], [3,25]]])
        [selection1, selection2, selection3] = editor.getSelections()

        editor.selectDown()
        expect(editor.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 9], [4, 25]])
        expect(selection1.isReversed()).toBeFalsy()

      it "merges selections when they intersect when moving up", ->
        editor.setSelectedBufferRanges([[[0,9], [0,13]], [[1,10], [1,20]]], reversed: true)
        [selection1, selection2] = editor.getSelections()

        editor.selectUp()
        expect(editor.getSelections().length).toBe 1
        expect(editor.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 0], [1, 20]])
        expect(selection1.isReversed()).toBeTruthy()

      it "merges selections when they intersect when moving left", ->
        editor.setSelectedBufferRanges([[[0,9], [0,13]], [[0,13], [1,20]]], reversed: true)
        [selection1, selection2] = editor.getSelections()

        editor.selectLeft()
        expect(editor.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 8], [1, 20]])
        expect(selection1.isReversed()).toBeTruthy()

      it "merges selections when they intersect when moving right", ->
        editor.setSelectedBufferRanges([[[0,9], [0,14]], [[0,14], [1,20]]])
        [selection1, selection2] = editor.getSelections()

        editor.selectRight()
        expect(editor.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 9], [1, 21]])
        expect(selection1.isReversed()).toBeFalsy()

      describe "when counts are passed into the selection functions", ->
        it "expands each selection to its cursor's new location", ->
          editor.setSelectedBufferRanges([[[0,9], [0,13]], [[3,16], [3,21]]])
          [selection1, selection2] = editor.getSelections()

          editor.selectRight(2)
          expect(selection1.getBufferRange()).toEqual [[0,9], [0,15]]
          expect(selection2.getBufferRange()).toEqual [[3,16], [3,23]]

          editor.selectLeft(3)
          expect(selection1.getBufferRange()).toEqual [[0,9], [0,12]]
          expect(selection2.getBufferRange()).toEqual [[3,16], [3,20]]

          editor.selectDown(3)
          expect(selection1.getBufferRange()).toEqual [[0,9], [3,12]]
          expect(selection2.getBufferRange()).toEqual [[3,16], [6,20]]

          editor.selectUp(2)
          expect(selection1.getBufferRange()).toEqual [[0,9], [1,12]]
          expect(selection2.getBufferRange()).toEqual [[3,16], [4,20]]

    describe ".selectToBufferPosition(bufferPosition)", ->
      it "expands the last selection to the given position", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])
        editor.addCursorAtBufferPosition([5, 6])
        editor.selectToBufferPosition([6, 2])

        selections = editor.getSelections()
        expect(selections.length).toBe 2
        [selection1, selection2] = selections
        expect(selection1.getBufferRange()).toEqual [[3, 0], [4, 5]]
        expect(selection2.getBufferRange()).toEqual [[5, 6], [6, 2]]

    describe ".selectToScreenPosition(screenPosition)", ->
      it "expands the last selection to the given position", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])
        editor.addCursorAtScreenPosition([5, 6])
        editor.selectToScreenPosition([6, 2])

        selections = editor.getSelections()
        expect(selections.length).toBe 2
        [selection1, selection2] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 0], [4, 5]]
        expect(selection2.getScreenRange()).toEqual [[5, 6], [6, 2]]

    describe ".selectToBeginningOfNextParagraph()", ->
      it "selects from the cursor to first line of the next paragraph", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])
        editor.addCursorAtScreenPosition([5, 6])
        editor.selectToScreenPosition([6, 2])

        editor.selectToBeginningOfNextParagraph()

        selections = editor.getSelections()
        expect(selections.length).toBe 1
        expect(selections[0].getScreenRange()).toEqual [[3, 0], [10, 0]]

    describe ".selectToBeginningOfPreviousParagraph()", ->
      it "selects from the cursor to the first line of the pevious paragraph", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])
        editor.addCursorAtScreenPosition([5, 6])
        editor.selectToScreenPosition([6, 2])

        editor.selectToBeginningOfPreviousParagraph()

        selections = editor.getSelections()
        expect(selections.length).toBe 1
        expect(selections[0].getScreenRange()).toEqual [[0, 0], [5, 6]]

      it "merges selections if they intersect, maintaining the directionality of the last selection", ->
        editor.setCursorScreenPosition([4, 10])
        editor.selectToScreenPosition([5, 27])
        editor.addCursorAtScreenPosition([3, 10])
        editor.selectToScreenPosition([6, 27])

        selections = editor.getSelections()
        expect(selections.length).toBe 1
        [selection1] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 10], [6, 27]]
        expect(selection1.isReversed()).toBeFalsy()

        editor.addCursorAtScreenPosition([7, 4])
        editor.selectToScreenPosition([4, 11])

        selections = editor.getSelections()
        expect(selections.length).toBe 1
        [selection1] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 10], [7, 4]]
        expect(selection1.isReversed()).toBeTruthy()

    describe ".selectToTop()", ->
      it "selects text from cusor position to the top of the buffer", ->
        editor.setCursorScreenPosition [11,2]
        editor.addCursorAtScreenPosition [10,0]
        editor.selectToTop()
        expect(editor.getCursors().length).toBe 1
        expect(editor.getCursorBufferPosition()).toEqual [0,0]
        expect(editor.getLastSelection().getBufferRange()).toEqual [[0,0], [11,2]]
        expect(editor.getLastSelection().isReversed()).toBeTruthy()

    describe ".selectToBottom()", ->
      it "selects text from cusor position to the bottom of the buffer", ->
        editor.setCursorScreenPosition [10,0]
        editor.addCursorAtScreenPosition [9,3]
        editor.selectToBottom()
        expect(editor.getCursors().length).toBe 1
        expect(editor.getCursorBufferPosition()).toEqual [12,2]
        expect(editor.getLastSelection().getBufferRange()).toEqual [[9,3], [12,2]]
        expect(editor.getLastSelection().isReversed()).toBeFalsy()

    describe ".selectAll()", ->
      it "selects the entire buffer", ->
        editor.selectAll()
        expect(editor.getLastSelection().getBufferRange()).toEqual buffer.getRange()

    describe ".selectToBeginningOfLine()", ->
      it "selects text from cusor position to beginning of line", ->
        editor.setCursorScreenPosition [12,2]
        editor.addCursorAtScreenPosition [11,3]

        editor.selectToBeginningOfLine()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [12,0]
        expect(cursor2.getBufferPosition()).toEqual [11,0]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[12,0], [12,2]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[11,0], [11,3]]
        expect(selection2.isReversed()).toBeTruthy()

    describe ".selectToEndOfLine()", ->
      it "selects text from cusor position to end of line", ->
        editor.setCursorScreenPosition [12,0]
        editor.addCursorAtScreenPosition [11,3]

        editor.selectToEndOfLine()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [12,2]
        expect(cursor2.getBufferPosition()).toEqual [11,44]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[12,0], [12,2]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[11,3], [11,44]]
        expect(selection2.isReversed()).toBeFalsy()

    describe ".selectLinesContainingCursors()", ->
      it "selects the entire line (including newlines) at given row", ->
        editor.setCursorScreenPosition([1, 2])
        editor.selectLinesContainingCursors()
        expect(editor.getSelectedBufferRange()).toEqual [[1,0], [2,0]]
        expect(editor.getSelectedText()).toBe "  var sort = function(items) {\n"

        editor.setCursorScreenPosition([12, 2])
        editor.selectLinesContainingCursors()
        expect(editor.getSelectedBufferRange()).toEqual [[12,0], [12,2]]

        editor.setCursorBufferPosition([0, 2])
        editor.selectLinesContainingCursors()
        editor.selectLinesContainingCursors()
        expect(editor.getSelectedBufferRange()).toEqual [[0,0], [2,0]]

      it "autoscrolls to the selection", ->
        editor.setLineHeightInPixels(10)
        editor.setDefaultCharWidth(10)
        editor.setHeight(50)
        editor.setWidth(50)
        editor.setHorizontalScrollbarHeight(0)
        editor.setCursorScreenPosition([5, 6])

        editor.scrollToTop()
        expect(editor.getScrollTop()).toBe 0

        editor.selectLinesContainingCursors()
        expect(editor.getScrollBottom()).toBe (7 + editor.getVerticalScrollMargin()) * 10

    describe ".selectToBeginningOfWord()", ->
      it "selects text from cusor position to beginning of word", ->
        editor.setCursorScreenPosition [0,13]
        editor.addCursorAtScreenPosition [3,49]

        editor.selectToBeginningOfWord()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0,4]
        expect(cursor2.getBufferPosition()).toEqual [3,47]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0,4], [0,13]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[3,47], [3,49]]
        expect(selection2.isReversed()).toBeTruthy()

    describe ".selectToEndOfWord()", ->
      it "selects text from cusor position to end of word", ->
        editor.setCursorScreenPosition [0,4]
        editor.addCursorAtScreenPosition [3,48]

        editor.selectToEndOfWord()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0,13]
        expect(cursor2.getBufferPosition()).toEqual [3,50]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0,4], [0,13]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[3,48], [3,50]]
        expect(selection2.isReversed()).toBeFalsy()

    describe ".selectToBeginningOfNextWord()", ->
      it "selects text from cusor position to beginning of next word", ->
        editor.setCursorScreenPosition [0,4]
        editor.addCursorAtScreenPosition [3,48]

        editor.selectToBeginningOfNextWord()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0,14]
        expect(cursor2.getBufferPosition()).toEqual [3,51]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0,4], [0,14]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[3,48], [3,51]]
        expect(selection2.isReversed()).toBeFalsy()

    describe ".selectToPreviousWordBoundary()", ->
      it "select to the previous word boundary", ->
        editor.setCursorBufferPosition [0, 8]
        editor.addCursorAtBufferPosition [2, 0]
        editor.addCursorAtBufferPosition [3, 4]
        editor.addCursorAtBufferPosition [3, 14]

        editor.selectToPreviousWordBoundary()

        expect(editor.getSelections().length).toBe 4
        [selection1, selection2, selection3, selection4] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0,8], [0,4]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[2,0], [1,30]]
        expect(selection2.isReversed()).toBeTruthy()
        expect(selection3.getBufferRange()).toEqual [[3,4], [3,0]]
        expect(selection3.isReversed()).toBeTruthy()
        expect(selection4.getBufferRange()).toEqual [[3,14], [3,13]]
        expect(selection4.isReversed()).toBeTruthy()

    describe ".selectToNextWordBoundary()", ->
      it "select to the next word boundary", ->
        editor.setCursorBufferPosition [0, 8]
        editor.addCursorAtBufferPosition [2, 40]
        editor.addCursorAtBufferPosition [4, 0]
        editor.addCursorAtBufferPosition [3, 30]

        editor.selectToNextWordBoundary()

        expect(editor.getSelections().length).toBe 4
        [selection1, selection2, selection3, selection4] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0,8], [0,13]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[2,40], [3,0]]
        expect(selection2.isReversed()).toBeFalsy()
        expect(selection3.getBufferRange()).toEqual [[4,0], [4,4]]
        expect(selection3.isReversed()).toBeFalsy()
        expect(selection4.getBufferRange()).toEqual [[3,30], [3,31]]
        expect(selection4.isReversed()).toBeFalsy()

    describe ".selectWordsContainingCursors()", ->
      describe "when the cursor is inside a word", ->
        it "selects the entire word", ->
          editor.setCursorScreenPosition([0, 8])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedText()).toBe 'quicksort'

      describe "when the cursor is between two words", ->
        it "selects the word the cursor is on", ->
          editor.setCursorScreenPosition([0, 4])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedText()).toBe 'quicksort'

          editor.setCursorScreenPosition([0, 3])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedText()).toBe 'var'

      describe "when the cursor is inside a region of whitespace", ->
        it "selects the whitespace region", ->
          editor.setCursorScreenPosition([5, 2])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedBufferRange()).toEqual [[5, 0], [5, 6]]

          editor.setCursorScreenPosition([5, 0])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedBufferRange()).toEqual [[5, 0], [5, 6]]

      describe "when the cursor is at the end of the text", ->
        it "select the previous word", ->
          editor.buffer.append 'word'
          editor.moveToBottom()
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedBufferRange()).toEqual [[12, 2], [12, 6]]

      describe 'when editor.nonWordCharacters is set scoped to a grammar', ->
        coffeeEditor = null
        beforeEach ->
          waitsForPromise ->
            atom.packages.activatePackage('language-coffee-script')
          waitsForPromise ->
            atom.project.open('coffee.coffee', autoIndent: false).then (o) -> coffeeEditor = o

        it 'selects the correct surrounding word for the given scoped setting', ->
          coffeeEditor.setCursorBufferPosition [0, 9] # in the middle of quicksort
          coffeeEditor.selectWordsContainingCursors()
          expect(coffeeEditor.getSelectedBufferRange()).toEqual [[0, 6], [0, 15]]

          atom.config.set 'editor.nonWordCharacters', 'qusort', scopeSelector: '.source.coffee'

          coffeeEditor.setCursorBufferPosition [0, 9]
          coffeeEditor.selectWordsContainingCursors()
          expect(coffeeEditor.getSelectedBufferRange()).toEqual [[0, 8], [0, 11]]

          editor.setCursorBufferPosition [0, 7]
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedBufferRange()).toEqual [[0, 4], [0, 13]]

    describe ".selectToFirstCharacterOfLine()", ->
      it "moves to the first character of the current line or the beginning of the line if it's already on the first character", ->
        editor.setCursorScreenPosition [0,5]
        editor.addCursorAtScreenPosition [1,7]

        editor.selectToFirstCharacterOfLine()

        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0,0]
        expect(cursor2.getBufferPosition()).toEqual [1,2]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0,0], [0,5]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[1,2], [1,7]]
        expect(selection2.isReversed()).toBeTruthy()

        editor.selectToFirstCharacterOfLine()
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0,0], [0,5]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[1,0], [1,7]]
        expect(selection2.isReversed()).toBeTruthy()

    describe ".setSelectedBufferRanges(ranges)", ->
      it "clears existing selections and creates selections for each of the given ranges", ->
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[4, 4], [5, 5]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[2, 2], [3, 3]], [[4, 4], [5, 5]]]

        editor.setSelectedBufferRanges([[[5, 5], [6, 6]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[5, 5], [6, 6]]]

      it "merges intersecting selections", ->
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 0], [5, 5]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[2, 2], [5, 5]]]

      it "does not merge non-empty adjacent selections", ->
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 3], [5, 5]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[2, 2], [3, 3]], [[3, 3], [5, 5]]]

      it "recyles existing selection instances", ->
        selection = editor.getLastSelection()
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[4, 4], [5, 5]]])

        [selection1, selection2] = editor.getSelections()
        expect(selection1).toBe selection
        expect(selection1.getBufferRange()).toEqual [[2, 2], [3, 3]]

      describe "when the 'preserveFolds' option is false (the default)", ->
        it "removes folds that contain the selections", ->
          editor.setSelectedBufferRange([[0,0], [0,0]])
          editor.createFold(1, 4)
          editor.createFold(2, 3)
          editor.createFold(6, 8)
          editor.createFold(10, 11)

          editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[6, 6], [7, 7]]])
          expect(editor.tokenizedLineForScreenRow(1).fold).toBeUndefined()
          expect(editor.tokenizedLineForScreenRow(2).fold).toBeUndefined()
          expect(editor.tokenizedLineForScreenRow(6).fold).toBeUndefined()
          expect(editor.tokenizedLineForScreenRow(10).fold).toBeDefined()

      describe "when the 'preserveFolds' option is true", ->
        it "does not remove folds that contain the selections", ->
          editor.setSelectedBufferRange([[0,0], [0,0]])
          editor.createFold(1, 4)
          editor.createFold(6, 8)
          editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[6, 0], [6, 1]]], preserveFolds: true)
          expect(editor.isFoldedAtBufferRow(1)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()

    describe ".setSelectedScreenRanges(ranges)", ->
      beforeEach ->
        editor.foldBufferRow(4)

      it "clears existing selections and creates selections for each of the given ranges", ->
        editor.setSelectedScreenRanges([[[3, 4], [3, 7]], [[5, 4], [5, 7]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[3, 4], [3, 7]], [[8, 4], [8, 7]]]

        editor.setSelectedScreenRanges([[[6, 2], [6, 4]]])
        expect(editor.getSelectedScreenRanges()).toEqual [[[6, 2], [6, 4]]]

      it "merges intersecting selections and unfolds the fold which contain them", ->
        editor.foldBufferRow(0)

        # Use buffer ranges because only the first line is on screen
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 0], [5, 5]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[2, 2], [5, 5]]]

      it "recyles existing selection instances", ->
        selection = editor.getLastSelection()
        editor.setSelectedScreenRanges([[[2, 2], [3, 4]], [[4, 4], [5, 5]]])

        [selection1, selection2] = editor.getSelections()
        expect(selection1).toBe selection
        expect(selection1.getScreenRange()).toEqual [[2, 2], [3, 4]]

    describe ".setSelectedBufferRange(range)", ->
      it "autoscrolls the selection if it is last unless the 'autoscroll' option is false", ->
        editor.setVerticalScrollMargin(2)
        editor.setHorizontalScrollMargin(2)
        editor.setLineHeightInPixels(10)
        editor.setDefaultCharWidth(10)
        editor.setHeight(70)
        editor.setWidth(100)
        editor.setHorizontalScrollbarHeight(0)

        expect(editor.getScrollTop()).toBe 0

        editor.setSelectedBufferRange([[5, 6], [6, 8]])
        expect(editor.getScrollBottom()).toBe (7 + editor.getVerticalScrollMargin()) * 10
        expect(editor.getScrollRight()).toBe (8 + editor.getHorizontalScrollMargin()) * 10

        editor.setSelectedBufferRange([[0, 0], [0, 0]])
        expect(editor.getScrollTop()).toBe 0
        expect(editor.getScrollLeft()).toBe 0

        editor.setSelectedBufferRange([[6, 6], [6, 8]])
        expect(editor.getScrollBottom()).toBe (7 + editor.getVerticalScrollMargin()) * 10
        expect(editor.getScrollRight()).toBe (8 + editor.getHorizontalScrollMargin()) * 10

    describe ".selectMarker(marker)", ->
      describe "if the marker is valid", ->
        it "selects the marker's range and returns the selected range", ->
          marker = editor.markBufferRange([[0, 1], [3, 3]])
          expect(editor.selectMarker(marker)).toEqual [[0, 1], [3, 3]]
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [3, 3]]

      describe "if the marker is invalid", ->
        it "does not change the selection and returns a falsy value", ->
          marker = editor.markBufferRange([[0, 1], [3, 3]])
          marker.destroy()
          expect(editor.selectMarker(marker)).toBeFalsy()
          expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

    describe ".addSelectionForBufferRange(bufferRange)", ->
      it "adds a selection for the specified buffer range", ->
        editor.addSelectionForBufferRange([[3, 4], [5, 6]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [0, 0]], [[3, 4], [5, 6]]]

      it "autoscrolls to the added selection if needed", ->
        editor.setVerticalScrollMargin(2)
        editor.setHorizontalScrollMargin(2)
        editor.setLineHeightInPixels(10)
        editor.setDefaultCharWidth(10)
        editor.setHeight(80)
        editor.setWidth(100)
        editor.addSelectionForBufferRange([[8, 10], [8, 15]])
        expect(editor.getScrollBottom()).toBe (9 * 10) + (2 * 10)
        expect(editor.getScrollRight()).toBe (15 * 10) + (2 * 10)

    describe ".addSelectionBelow()", ->
      describe "when the selection is non-empty", ->
        it "selects the same region of the line below current selections if possible", ->
          editor.setSelectedBufferRange([[3, 16], [3, 21]])
          editor.addSelectionForBufferRange([[3, 25], [3, 34]])
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 16], [3, 21]]
            [[3, 25], [3, 34]]
            [[4, 16], [4, 21]]
            [[4, 25], [4, 29]]
          ]
          for cursor in editor.getCursors()
            expect(cursor.isVisible()).toBeFalsy()

        it "skips lines that are too short to create a non-empty selection", ->
          editor.setSelectedBufferRange([[3, 31], [3, 38]])
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 31], [3, 38]]
            [[6, 31], [6, 38]]
          ]

        it "honors the original selection's range (goal range) when adding across shorter lines", ->
          editor.setSelectedBufferRange([[3, 22], [3, 38]])
          editor.addSelectionBelow()
          editor.addSelectionBelow()
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 22], [3, 38]]
            [[4, 22], [4, 29]]
            [[5, 22], [5, 30]]
            [[6, 22], [6, 38]]
          ]

        it "clears selection goal ranges when the selection changes", ->
          editor.setSelectedBufferRange([[3, 22], [3, 38]])
          editor.addSelectionBelow()
          editor.selectLeft()
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 22], [3, 37]]
            [[4, 22], [4, 29]]
            [[5, 22], [5, 28]]
          ]

          # goal range from previous add selection is honored next time
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 22], [3, 37]]
            [[4, 22], [4, 29]]
            [[5, 22], [5, 30]] # select to end of line 5 because line 4's goal range was reset by line 3 previously
            [[6, 22], [6, 28]]
          ]

        it "can add selections to soft-wrapped line segments", ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(40)

          editor.setSelectedScreenRange([[3, 10], [3, 15]])
          editor.addSelectionBelow()
          expect(editor.getSelectedScreenRanges()).toEqual [
            [[3, 10], [3, 15]]
            [[4, 10], [4, 15]]
          ]

        it "takes atomic tokens into account", ->
          waitsForPromise ->
            atom.project.open('sample-with-tabs-and-leading-comment.coffee', autoIndent: false).then (o) -> editor = o

          runs ->
            editor.setSelectedBufferRange([[2, 1], [2, 3]])
            editor.addSelectionBelow()

            expect(editor.getSelectedBufferRanges()).toEqual [
              [[2, 1], [2, 3]]
              [[3, 1], [3, 2]]
            ]

      describe "when the selection is empty", ->
        describe "when lines are soft-wrapped", ->
          beforeEach ->
            editor.setSoftWrapped(true)
            editor.setEditorWidthInChars(40)

          it "skips soft-wrap indentation tokens", ->
            editor.setCursorScreenPosition([3, 0])
            editor.addSelectionBelow()

            expect(editor.getSelectedScreenRanges()).toEqual [
              [[3, 0], [3, 0]]
              [[4, 4], [4, 4]]
            ]

          it "does not skip them if they're shorter than the current column", ->
            editor.setCursorScreenPosition([3, 37])
            editor.addSelectionBelow()

            expect(editor.getSelectedScreenRanges()).toEqual [
              [[3, 37], [3, 37]]
              [[4, 26], [4, 26]]
            ]

        it "does not skip lines that are shorter than the current column", ->
          editor.setCursorBufferPosition([3, 36])
          editor.addSelectionBelow()
          editor.addSelectionBelow()
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 36], [3, 36]]
            [[4, 29], [4, 29]]
            [[5, 30], [5, 30]]
            [[6, 36], [6, 36]]
          ]

        it "skips empty lines when the column is non-zero", ->
          editor.setCursorBufferPosition([9, 4])
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[9, 4], [9, 4]]
            [[11, 4], [11, 4]]
          ]

        it "does not skip empty lines when the column is zero", ->
          editor.setCursorBufferPosition([9, 0])
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[9, 0], [9, 0]]
            [[10, 0], [10, 0]]
          ]

    describe ".addSelectionAbove()", ->
      describe "when the selection is non-empty", ->
        it "selects the same region of the line above current selections if possible", ->
          editor.setSelectedBufferRange([[3, 16], [3, 21]])
          editor.addSelectionForBufferRange([[3, 37], [3, 44]])
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 16], [3, 21]]
            [[3, 37], [3, 44]]
            [[2, 16], [2, 21]]
            [[2, 37], [2, 40]]
          ]
          for cursor in editor.getCursors()
            expect(cursor.isVisible()).toBeFalsy()

        it "skips lines that are too short to create a non-empty selection", ->
          editor.setSelectedBufferRange([[6, 31], [6, 38]])
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[6, 31], [6, 38]]
            [[3, 31], [3, 38]]
          ]

        it "honors the original selection's range (goal range) when adding across shorter lines", ->
          editor.setSelectedBufferRange([[6, 22], [6, 38]])
          editor.addSelectionAbove()
          editor.addSelectionAbove()
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[6, 22], [6, 38]]
            [[5, 22], [5, 30]]
            [[4, 22], [4, 29]]
            [[3, 22], [3, 38]]
          ]

        it "can add selections to soft-wrapped line segments", ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(40)

          editor.setSelectedScreenRange([[4, 10], [4, 15]])
          editor.addSelectionAbove()
          expect(editor.getSelectedScreenRanges()).toEqual [
            [[4, 10], [4, 15]]
            [[3, 10], [3, 15]]
          ]

        it "takes atomic tokens into account", ->
          waitsForPromise ->
            atom.project.open('sample-with-tabs-and-leading-comment.coffee', autoIndent: false).then (o) -> editor = o

          runs ->
            editor.setSelectedBufferRange([[3, 1], [3, 2]])
            editor.addSelectionAbove()

            expect(editor.getSelectedBufferRanges()).toEqual [
              [[3, 1], [3, 2]]
              [[2, 1], [2, 3]]
            ]

      describe "when the selection is empty", ->
        describe "when lines are soft-wrapped", ->
          beforeEach ->
            editor.setSoftWrapped(true)
            editor.setEditorWidthInChars(40)

          it "skips soft-wrap indentation tokens", ->
            editor.setCursorScreenPosition([5, 0])
            editor.addSelectionAbove()

            expect(editor.getSelectedScreenRanges()).toEqual [
              [[5, 0], [5, 0]]
              [[4, 4], [4, 4]]
            ]

          it "does not skip them if they're shorter than the current column", ->
            editor.setCursorScreenPosition([5, 29])
            editor.addSelectionAbove()

            expect(editor.getSelectedScreenRanges()).toEqual [
              [[5, 29], [5, 29]]
              [[4, 26], [4, 26]]
            ]

        it "does not skip lines that are shorter than the current column", ->
          editor.setCursorBufferPosition([6, 36])
          editor.addSelectionAbove()
          editor.addSelectionAbove()
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[6, 36], [6, 36]]
            [[5, 30], [5, 30]]
            [[4, 29], [4, 29]]
            [[3, 36], [3, 36]]
          ]

        it "skips empty lines when the column is non-zero", ->
          editor.setCursorBufferPosition([11, 4])
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[11, 4], [11, 4]]
            [[9, 4], [9, 4]]
          ]

        it "does not skip empty lines when the column is zero", ->
          editor.setCursorBufferPosition([10, 0])
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[10, 0], [10, 0]]
            [[9, 0], [9, 0]]
          ]

    describe ".splitSelectionsIntoLines()", ->
      it "splits all multi-line selections into one selection per line", ->
        editor.setSelectedBufferRange([[0, 3], [2, 4]])
        editor.splitSelectionsIntoLines()
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 3], [0, 29]]
          [[1, 0], [1, 30]]
          [[2, 0], [2, 4]]
        ]

        editor.setSelectedBufferRange([[0, 3], [1, 10]])
        editor.splitSelectionsIntoLines()
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 3], [0, 29]]
          [[1, 0], [1, 10]]
        ]

        editor.setSelectedBufferRange([[0, 0], [0, 3]])
        editor.splitSelectionsIntoLines()
        expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [0, 3]]]

    describe ".consolidateSelections()", ->
      it "destroys all selections but the most recent, returning true if any selections were destroyed", ->
        editor.setSelectedBufferRange([[3, 16], [3, 21]])
        selection1 = editor.getLastSelection()
        selection2 = editor.addSelectionForBufferRange([[3, 25], [3, 34]])
        selection3 = editor.addSelectionForBufferRange([[8, 4], [8, 10]])

        expect(editor.getSelections()).toEqual [selection1, selection2, selection3]
        expect(editor.consolidateSelections()).toBeTruthy()
        expect(editor.getSelections()).toEqual [selection3]
        expect(selection3.isEmpty()).toBeFalsy()
        expect(editor.consolidateSelections()).toBeFalsy()
        expect(editor.getSelections()).toEqual [selection3]

    describe "when the cursor is moved while there is a selection", ->
      makeSelection = -> selection.setBufferRange [[1, 2], [1, 5]]

      it "clears the selection", ->
        makeSelection()
        editor.moveDown()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editor.moveUp()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editor.moveLeft()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editor.moveRight()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editor.setCursorScreenPosition([3, 3])
        expect(selection.isEmpty()).toBeTruthy()

    it "does not share selections between different edit sessions for the same buffer", ->
      editor2 = null
      waitsForPromise ->
        atom.project.open('sample.js').then (o) -> editor2 = o

      runs ->
        editor.setSelectedBufferRanges([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
        editor2.setSelectedBufferRanges([[[8, 7], [6, 5]], [[4, 3], [2, 1]]])
        expect(editor2.getSelectedBufferRanges()).not.toEqual editor.getSelectedBufferRanges()

  describe "buffer manipulation", ->
    describe ".insertText(text)", ->
      describe "when there is a single selection", ->
        beforeEach ->
          editor.setSelectedBufferRange([[1, 0], [1, 2]])

        it "replaces the selection with the given text", ->
          range = editor.insertText('xxx')
          expect(range).toEqual [ [[1, 0], [1, 3]] ]
          expect(buffer.lineForRow(1)).toBe 'xxxvar sort = function(items) {'

      describe "when there are multiple empty selections", ->
        describe "when the cursors are on the same line", ->
          it "inserts the given text at the location of each cursor and moves the cursors to the end of each cursor's inserted text", ->
            editor.setCursorScreenPosition([1, 2])
            editor.addCursorAtScreenPosition([1, 5])

            editor.insertText('xxx')

            expect(buffer.lineForRow(1)).toBe '  xxxvarxxx sort = function(items) {'
            [cursor1, cursor2] = editor.getCursors()

            expect(cursor1.getBufferPosition()).toEqual [1, 5]
            expect(cursor2.getBufferPosition()).toEqual [1, 11]

        describe "when the cursors are on different lines", ->
          it "inserts the given text at the location of each cursor and moves the cursors to the end of each cursor's inserted text", ->
            editor.setCursorScreenPosition([1, 2])
            editor.addCursorAtScreenPosition([2, 4])

            editor.insertText('xxx')

            expect(buffer.lineForRow(1)).toBe '  xxxvar sort = function(items) {'
            expect(buffer.lineForRow(2)).toBe '    xxxif (items.length <= 1) return items;'
            [cursor1, cursor2] = editor.getCursors()

            expect(cursor1.getBufferPosition()).toEqual [1, 5]
            expect(cursor2.getBufferPosition()).toEqual [2, 7]

          it "autoscrolls to the last cursor", ->
            editor.setCursorScreenPosition([1, 2])
            editor.addCursorAtScreenPosition([10, 4])
            editor.setLineHeightInPixels(10)
            editor.setHeight(50)

            expect(editor.getScrollTop()).toBe 0
            editor.insertText('a')
            expect(editor.getScrollTop()).toBe 80

      describe "when there are multiple non-empty selections", ->
        describe "when the selections are on the same line", ->
          it "replaces each selection range with the inserted characters", ->
            editor.setSelectedBufferRanges([[[0,4], [0,13]], [[0,22], [0,24]]])
            editor.insertText("x")

            [cursor1, cursor2] = editor.getCursors()
            [selection1, selection2] = editor.getSelections()

            expect(cursor1.getScreenPosition()).toEqual [0, 5]
            expect(cursor2.getScreenPosition()).toEqual [0, 15]
            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection2.isEmpty()).toBeTruthy()

            expect(editor.lineTextForBufferRow(0)).toBe "var x = functix () {"

        describe "when the selections are on different lines", ->
          it "replaces each selection with the given text, clears the selections, and places the cursor at the end of each selection's inserted text", ->
            editor.setSelectedBufferRanges([[[1, 0], [1, 2]], [[2, 0], [2, 4]]])

            editor.insertText('xxx')

            expect(buffer.lineForRow(1)).toBe 'xxxvar sort = function(items) {'
            expect(buffer.lineForRow(2)).toBe 'xxxif (items.length <= 1) return items;'
            [selection1, selection2] = editor.getSelections()

            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection1.cursor.getBufferPosition()).toEqual [1, 3]
            expect(selection2.isEmpty()).toBeTruthy()
            expect(selection2.cursor.getBufferPosition()).toEqual [2, 3]

      describe "when there is a selection that ends on a folded line", ->
        it "destroys the selection", ->
          editor.createFold(2,4)
          editor.setSelectedBufferRange([[1,0], [2,0]])
          editor.insertText('holy cow')
          expect(editor.tokenizedLineForScreenRow(2).fold).toBeUndefined()

      describe "when there are ::onWillInsertText and ::onDidInsertText observers", ->
        beforeEach ->
          editor.setSelectedBufferRange([[1, 0], [1, 2]])

        it "notifies the observers when inserting text", ->
          willInsertSpy = jasmine.createSpy().andCallFake ->
            expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {'

          didInsertSpy = jasmine.createSpy().andCallFake ->
            expect(buffer.lineForRow(1)).toBe 'xxxvar sort = function(items) {'

          editor.onWillInsertText(willInsertSpy)
          editor.onDidInsertText(didInsertSpy)

          expect(editor.insertText('xxx')).toBeTruthy()
          expect(buffer.lineForRow(1)).toBe 'xxxvar sort = function(items) {'

          expect(willInsertSpy).toHaveBeenCalled()
          expect(didInsertSpy).toHaveBeenCalled()

          options = willInsertSpy.mostRecentCall.args[0]
          expect(options.text).toBe 'xxx'
          expect(options.cancel).toBeDefined()

          options = didInsertSpy.mostRecentCall.args[0]
          expect(options.text).toBe 'xxx'

        it "cancels text insertion when an ::onWillInsertText observer calls cancel on an event", ->
          willInsertSpy = jasmine.createSpy().andCallFake ({cancel}) ->
            cancel()

          didInsertSpy = jasmine.createSpy()

          editor.onWillInsertText(willInsertSpy)
          editor.onDidInsertText(didInsertSpy)

          expect(editor.insertText('xxx')).toBe false
          expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {'

          expect(willInsertSpy).toHaveBeenCalled()
          expect(didInsertSpy).not.toHaveBeenCalled()

      describe "when the undo option is set to 'skip'", ->
        beforeEach ->
          editor.setSelectedBufferRange([[1, 2], [1, 2]])

        it "does not undo the skipped operation", ->
          range = editor.insertText('x')
          range = editor.insertText('y', undo: 'skip')
          editor.undo()
          expect(buffer.lineForRow(1)).toBe '  yvar sort = function(items) {'

    describe ".insertNewline()", ->
      describe "when there is a single cursor", ->
        describe "when the cursor is at the beginning of a line", ->
          it "inserts an empty line before it", ->
            editor.setCursorScreenPosition(row: 1, column: 0)

            editor.insertNewline()

            expect(buffer.lineForRow(1)).toBe ''
            expect(editor.getCursorScreenPosition()).toEqual(row: 2, column: 0)

        describe "when the cursor is in the middle of a line", ->
          it "splits the current line to form a new line", ->
            editor.setCursorScreenPosition(row: 1, column: 6)
            originalLine = buffer.lineForRow(1)
            lineBelowOriginalLine = buffer.lineForRow(2)

            editor.insertNewline()

            expect(buffer.lineForRow(1)).toBe originalLine[0...6]
            expect(buffer.lineForRow(2)).toBe originalLine[6..]
            expect(buffer.lineForRow(3)).toBe lineBelowOriginalLine
            expect(editor.getCursorScreenPosition()).toEqual(row: 2, column: 0)

        describe "when the cursor is on the end of a line", ->
          it "inserts an empty line after it", ->
            editor.setCursorScreenPosition(row: 1, column: buffer.lineForRow(1).length)

            editor.insertNewline()

            expect(buffer.lineForRow(2)).toBe ''
            expect(editor.getCursorScreenPosition()).toEqual(row: 2, column: 0)

      describe "when there are multiple cursors", ->
        describe "when the cursors are on the same line", ->
          it "breaks the line at the cursor locations", ->
            editor.setCursorScreenPosition([3, 13])
            editor.addCursorAtScreenPosition([3, 38])

            editor.insertNewline()

            expect(editor.lineTextForBufferRow(3)).toBe "    var pivot"
            expect(editor.lineTextForBufferRow(4)).toBe " = items.shift(), current"
            expect(editor.lineTextForBufferRow(5)).toBe ", left = [], right = [];"
            expect(editor.lineTextForBufferRow(6)).toBe "    while(items.length > 0) {"

            [cursor1, cursor2] = editor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [4, 0]
            expect(cursor2.getBufferPosition()).toEqual [5, 0]

        describe "when the cursors are on different lines", ->
          it "inserts newlines at each cursor location", ->
            editor.setCursorScreenPosition([3, 0])
            editor.addCursorAtScreenPosition([6, 0])

            editor.insertText("\n")
            expect(editor.lineTextForBufferRow(3)).toBe ""
            expect(editor.lineTextForBufferRow(4)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(5)).toBe "    while(items.length > 0) {"
            expect(editor.lineTextForBufferRow(6)).toBe "      current = items.shift();"
            expect(editor.lineTextForBufferRow(7)).toBe ""
            expect(editor.lineTextForBufferRow(8)).toBe "      current < pivot ? left.push(current) : right.push(current);"
            expect(editor.lineTextForBufferRow(9)).toBe "    }"

            [cursor1, cursor2] = editor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [4,0]
            expect(cursor2.getBufferPosition()).toEqual [8,0]

    describe ".insertNewlineBelow()", ->
      describe "when the operation is undone", ->
        it "places the cursor back at the previous location", ->
          editor.setCursorBufferPosition([0,2])
          editor.insertNewlineBelow()
          expect(editor.getCursorBufferPosition()).toEqual [1,0]
          editor.undo()
          expect(editor.getCursorBufferPosition()).toEqual [0,2]

      it "inserts a newline below the cursor's current line, autoindents it, and moves the cursor to the end of the line", ->
        atom.config.set("editor.autoIndent", true)
        editor.insertNewlineBelow()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe "  "
        expect(editor.getCursorBufferPosition()).toEqual [1, 2]

    describe ".insertNewlineAbove()", ->
      describe "when the cursor is on first line", ->
        it "inserts a newline on the first line and moves the cursor to the first line", ->
          editor.setCursorBufferPosition([0])
          editor.insertNewlineAbove()
          expect(editor.getCursorBufferPosition()).toEqual [0,0]
          expect(editor.lineTextForBufferRow(0)).toBe ''
          expect(editor.lineTextForBufferRow(1)).toBe 'var quicksort = function () {'
          expect(editor.buffer.getLineCount()).toBe 14

      describe "when the cursor is not on the first line", ->
        it "inserts a newline above the current line and moves the cursor to the inserted line", ->
          editor.setCursorBufferPosition([3,4])
          editor.insertNewlineAbove()
          expect(editor.getCursorBufferPosition()).toEqual [3,0]
          expect(editor.lineTextForBufferRow(3)).toBe ''
          expect(editor.lineTextForBufferRow(4)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
          expect(editor.buffer.getLineCount()).toBe 14

          editor.undo()
          expect(editor.getCursorBufferPosition()).toEqual [3,4]

      it "indents the new line to the correct level when editor.autoIndent is true", ->
        atom.config.set('editor.autoIndent', true)

        editor.setText('  var test')
        editor.setCursorBufferPosition([0,2])
        editor.insertNewlineAbove()

        expect(editor.getCursorBufferPosition()).toEqual [0,2]
        expect(editor.lineTextForBufferRow(0)).toBe '  '
        expect(editor.lineTextForBufferRow(1)).toBe '  var test'

        editor.setText('\n  var test')
        editor.setCursorBufferPosition([1,2])
        editor.insertNewlineAbove()

        expect(editor.getCursorBufferPosition()).toEqual [1,2]
        expect(editor.lineTextForBufferRow(0)).toBe ''
        expect(editor.lineTextForBufferRow(1)).toBe '  '
        expect(editor.lineTextForBufferRow(2)).toBe '  var test'

        editor.setText('function() {\n}')
        editor.setCursorBufferPosition([1,1])
        editor.insertNewlineAbove()

        expect(editor.getCursorBufferPosition()).toEqual [1,2]
        expect(editor.lineTextForBufferRow(0)).toBe 'function() {'
        expect(editor.lineTextForBufferRow(1)).toBe '  '
        expect(editor.lineTextForBufferRow(2)).toBe '}'

    describe "when a new line is appended before a closing tag (e.g. by pressing enter before a selection)", ->
      it "moves the line down and keeps the indentation level the same when editor.autoIndent is true", ->
        atom.config.set('editor.autoIndent', true)
        editor.setCursorBufferPosition([9,2])
        editor.insertNewline()
        expect(editor.lineTextForBufferRow(10)).toBe '  };'

    describe ".backspace()", ->
      describe "when there is a single cursor", ->
        changeScreenRangeHandler = null

        beforeEach ->
          selection = editor.getLastSelection()
          changeScreenRangeHandler = jasmine.createSpy('changeScreenRangeHandler')
          selection.onDidChangeRange changeScreenRangeHandler

        describe "when the cursor is on the middle of the line", ->
          it "removes the character before the cursor", ->
            editor.setCursorScreenPosition(row: 1, column: 7)
            expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"

            editor.backspace()

            line = buffer.lineForRow(1)
            expect(line).toBe "  var ort = function(items) {"
            expect(editor.getCursorScreenPosition()).toEqual {row: 1, column: 6}
            expect(changeScreenRangeHandler).toHaveBeenCalled()
            expect(editor.getLastCursor().isVisible()).toBeTruthy()

        describe "when the cursor is at the beginning of a line", ->
          it "joins it with the line above", ->
            originalLine0 = buffer.lineForRow(0)
            expect(originalLine0).toBe "var quicksort = function () {"
            expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"

            editor.setCursorScreenPosition(row: 1, column: 0)
            editor.backspace()

            line0 = buffer.lineForRow(0)
            line1 = buffer.lineForRow(1)
            expect(line0).toBe "var quicksort = function () {  var sort = function(items) {"
            expect(line1).toBe "    if (items.length <= 1) return items;"
            expect(editor.getCursorScreenPosition()).toEqual [0, originalLine0.length]

            expect(changeScreenRangeHandler).toHaveBeenCalled()

        describe "when the cursor is at the first column of the first line", ->
          it "does nothing, but doesn't raise an error", ->
            editor.setCursorScreenPosition(row: 0, column: 0)
            editor.backspace()

        describe "when the cursor is on the first column of a line below a fold", ->
          it "deletes the folded lines", ->
            editor.setCursorScreenPosition([4,0])
            editor.foldCurrentRow()
            editor.setCursorScreenPosition([5,0])
            editor.backspace()

            expect(buffer.lineForRow(4)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
            expect(buffer.lineForRow(4).fold).toBeUndefined()

        describe "when the cursor is in the middle of a line below a fold", ->
          it "backspaces as normal", ->
            editor.setCursorScreenPosition([4,0])
            editor.foldCurrentRow()
            editor.setCursorScreenPosition([5,5])
            editor.backspace()

            expect(buffer.lineForRow(7)).toBe "    }"
            expect(buffer.lineForRow(8)).toBe "    eturn sort(left).concat(pivot).concat(sort(right));"

        describe "when the cursor is on a folded screen line", ->
          it "deletes all of the folded lines along with the fold", ->
            editor.setCursorBufferPosition([3, 0])
            editor.foldCurrentRow()
            editor.backspace()

            expect(buffer.lineForRow(1)).toBe ""
            expect(buffer.lineForRow(2)).toBe "  return sort(Array.apply(this, arguments));"
            expect(editor.getCursorScreenPosition()).toEqual [1, 0]

      describe "when there are multiple cursors", ->
        describe "when cursors are on the same line", ->
          it "removes the characters preceding each cursor", ->
            editor.setCursorScreenPosition([3, 13])
            editor.addCursorAtScreenPosition([3, 38])

            editor.backspace()

            expect(editor.lineTextForBufferRow(3)).toBe "    var pivo = items.shift(), curren, left = [], right = [];"

            [cursor1, cursor2] = editor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [3, 12]
            expect(cursor2.getBufferPosition()).toEqual [3, 36]

            [selection1, selection2] = editor.getSelections()
            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection2.isEmpty()).toBeTruthy()

        describe "when cursors are on different lines", ->
          describe "when the cursors are in the middle of their lines", ->
            it "removes the characters preceding each cursor", ->
              editor.setCursorScreenPosition([3, 13])
              editor.addCursorAtScreenPosition([4, 10])

              editor.backspace()

              expect(editor.lineTextForBufferRow(3)).toBe "    var pivo = items.shift(), current, left = [], right = [];"
              expect(editor.lineTextForBufferRow(4)).toBe "    whileitems.length > 0) {"

              [cursor1, cursor2] = editor.getCursors()
              expect(cursor1.getBufferPosition()).toEqual [3, 12]
              expect(cursor2.getBufferPosition()).toEqual [4, 9]

              [selection1, selection2] = editor.getSelections()
              expect(selection1.isEmpty()).toBeTruthy()
              expect(selection2.isEmpty()).toBeTruthy()

          describe "when the cursors are on the first column of their lines", ->
            it "removes the newlines preceding each cursor", ->
              editor.setCursorScreenPosition([3, 0])
              editor.addCursorAtScreenPosition([6, 0])

              editor.backspace()
              expect(editor.lineTextForBufferRow(2)).toBe "    if (items.length <= 1) return items;    var pivot = items.shift(), current, left = [], right = [];"
              expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"
              expect(editor.lineTextForBufferRow(4)).toBe "      current = items.shift();      current < pivot ? left.push(current) : right.push(current);"
              expect(editor.lineTextForBufferRow(5)).toBe "    }"

              [cursor1, cursor2] = editor.getCursors()
              expect(cursor1.getBufferPosition()).toEqual [2,40]
              expect(cursor2.getBufferPosition()).toEqual [4,30]

      describe "when there is a single selection", ->
        it "deletes the selection, but not the character before it", ->
          editor.setSelectedBufferRange([[0,5], [0,9]])
          editor.backspace()
          expect(editor.buffer.lineForRow(0)).toBe 'var qsort = function () {'

        describe "when the selection ends on a folded line", ->
          it "preserves the fold", ->
            editor.setSelectedBufferRange([[3,0], [4,0]])
            editor.foldBufferRow(4)
            editor.backspace()

            expect(buffer.lineForRow(3)).toBe "    while(items.length > 0) {"
            expect(editor.tokenizedLineForScreenRow(3).fold).toBeDefined()

      describe "when there are multiple selections", ->
        it "removes all selected text", ->
          editor.setSelectedBufferRanges([[[0,4], [0,13]], [[0,16], [0,24]]])
          editor.backspace()
          expect(editor.lineTextForBufferRow(0)).toBe 'var  =  () {'

    describe ".deleteToBeginningOfWord()", ->
      describe "when no text is selected", ->
        it "deletes all text between the cursor and the beginning of the word", ->
          editor.setCursorBufferPosition([1, 24])
          editor.addCursorAtBufferPosition([3, 5])
          [cursor1, cursor2] = editor.getCursors()

          editor.deleteToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(ems) {'
          expect(buffer.lineForRow(3)).toBe '    ar pivot = items.shift(), current, left = [], right = [];'
          expect(cursor1.getBufferPosition()).toEqual [1, 22]
          expect(cursor2.getBufferPosition()).toEqual [3, 4]

          editor.deleteToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = functionems) {'
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return itemsar pivot = items.shift(), current, left = [], right = [];'
          expect(cursor1.getBufferPosition()).toEqual [1, 21]
          expect(cursor2.getBufferPosition()).toEqual [2, 39]

          editor.deleteToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = ems) {'
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return ar pivot = items.shift(), current, left = [], right = [];'
          expect(cursor1.getBufferPosition()).toEqual [1, 13]
          expect(cursor2.getBufferPosition()).toEqual [2, 34]

          editor.setText('  var sort')
          editor.setCursorBufferPosition([0, 2])
          editor.deleteToBeginningOfWord()
          expect(buffer.lineForRow(0)).toBe 'var sort'

      describe "when text is selected", ->
        it "deletes only selected text", ->
          editor.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
          editor.deleteToBeginningOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
          expect(buffer.lineForRow(2)).toBe 'if (items.length <= 1) return items;'

    describe '.deleteToEndOfLine()', ->
      describe 'when no text is selected', ->
        it 'deletes all text between the cursor and the end of the line', ->
          editor.setCursorBufferPosition([1, 24])
          editor.addCursorAtBufferPosition([2, 5])
          [cursor1, cursor2] = editor.getCursors()

          editor.deleteToEndOfLine()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it'
          expect(buffer.lineForRow(2)).toBe '    i'
          expect(cursor1.getBufferPosition()).toEqual [1, 24]
          expect(cursor2.getBufferPosition()).toEqual [2, 5]

        describe 'when at the end of the line', ->
          it 'deletes the next newline', ->
            editor.setCursorBufferPosition([1, 30])
            editor.deleteToEndOfLine()
            expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {    if (items.length <= 1) return items;'

      describe 'when text is selected', ->
        it 'deletes only the text in the selection', ->
          editor.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
          editor.deleteToEndOfLine()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
          expect(buffer.lineForRow(2)).toBe 'if (items.length <= 1) return items;'

    describe ".deleteToBeginningOfLine()", ->
      describe "when no text is selected", ->
        it "deletes all text between the cursor and the beginning of the line", ->
          editor.setCursorBufferPosition([1, 24])
          editor.addCursorAtBufferPosition([2, 5])
          [cursor1, cursor2] = editor.getCursors()

          editor.deleteToBeginningOfLine()
          expect(buffer.lineForRow(1)).toBe 'ems) {'
          expect(buffer.lineForRow(2)).toBe 'f (items.length <= 1) return items;'
          expect(cursor1.getBufferPosition()).toEqual [1, 0]
          expect(cursor2.getBufferPosition()).toEqual [2, 0]

        describe "when at the beginning of the line", ->
          it "deletes the newline", ->
            editor.setCursorBufferPosition([2])
            editor.deleteToBeginningOfLine()
            expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {    if (items.length <= 1) return items;'

      describe "when text is selected", ->
        it "still deletes all text to begginning of the line", ->
          editor.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
          editor.deleteToBeginningOfLine()
          expect(buffer.lineForRow(1)).toBe 'ems) {'
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;'

    describe ".delete()", ->
      describe "when there is a single cursor", ->
        describe "when the cursor is on the middle of a line", ->
          it "deletes the character following the cursor", ->
            editor.setCursorScreenPosition([1, 6])
            editor.delete()
            expect(buffer.lineForRow(1)).toBe '  var ort = function(items) {'

        describe "when the cursor is on the end of a line", ->
          it "joins the line with the following line", ->
            editor.setCursorScreenPosition([1, buffer.lineForRow(1).length])
            editor.delete()
            expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {    if (items.length <= 1) return items;'

        describe "when the cursor is on the last column of the last line", ->
          it "does nothing, but doesn't raise an error", ->
            editor.setCursorScreenPosition([12, buffer.lineForRow(12).length])
            editor.delete()
            expect(buffer.lineForRow(12)).toBe '};'

        describe "when the cursor is on the end of a line above a fold", ->
          it "only deletes the lines inside the fold", ->
            editor.foldBufferRow(4)
            editor.setCursorScreenPosition([3, Infinity])
            cursorPositionBefore = editor.getCursorScreenPosition()

            editor.delete()

            expect(buffer.lineForRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(buffer.lineForRow(4)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
            expect(editor.getCursorScreenPosition()).toEqual cursorPositionBefore

        describe "when the cursor is in the middle a line above a fold", ->
          it "deletes as normal", ->
            editor.foldBufferRow(4)
            editor.setCursorScreenPosition([3, 4])
            cursorPositionBefore = editor.getCursorScreenPosition()

            editor.delete()

            expect(buffer.lineForRow(3)).toBe "    ar pivot = items.shift(), current, left = [], right = [];"
            expect(editor.tokenizedLineForScreenRow(4).fold).toBeDefined()
            expect(editor.getCursorScreenPosition()).toEqual [3, 4]

        describe "when the cursor is on a folded line", ->
          it "removes the lines contained by the fold", ->
            editor.setSelectedBufferRange([[2, 0], [2, 0]])
            editor.createFold(2,4)
            editor.createFold(2,6)
            oldLine7 = buffer.lineForRow(7)
            oldLine8 = buffer.lineForRow(8)

            editor.delete()
            expect(editor.tokenizedLineForScreenRow(2).text).toBe oldLine7
            expect(editor.tokenizedLineForScreenRow(3).text).toBe oldLine8

      describe "when there are multiple cursors", ->
        describe "when cursors are on the same line", ->
          it "removes the characters following each cursor", ->
            editor.setCursorScreenPosition([3, 13])
            editor.addCursorAtScreenPosition([3, 38])

            editor.delete()

            expect(editor.lineTextForBufferRow(3)).toBe "    var pivot= items.shift(), current left = [], right = [];"

            [cursor1, cursor2] = editor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [3, 13]
            expect(cursor2.getBufferPosition()).toEqual [3, 37]

            [selection1, selection2] = editor.getSelections()
            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection2.isEmpty()).toBeTruthy()

        describe "when cursors are on different lines", ->
          describe "when the cursors are in the middle of the lines", ->
            it "removes the characters following each cursor", ->
              editor.setCursorScreenPosition([3, 13])
              editor.addCursorAtScreenPosition([4, 10])

              editor.delete()

              expect(editor.lineTextForBufferRow(3)).toBe "    var pivot= items.shift(), current, left = [], right = [];"
              expect(editor.lineTextForBufferRow(4)).toBe "    while(tems.length > 0) {"

              [cursor1, cursor2] = editor.getCursors()
              expect(cursor1.getBufferPosition()).toEqual [3, 13]
              expect(cursor2.getBufferPosition()).toEqual [4, 10]

              [selection1, selection2] = editor.getSelections()
              expect(selection1.isEmpty()).toBeTruthy()
              expect(selection2.isEmpty()).toBeTruthy()

          describe "when the cursors are at the end of their lines", ->
            it "removes the newlines following each cursor", ->
              editor.setCursorScreenPosition([0, 29])
              editor.addCursorAtScreenPosition([1, 30])

              editor.delete()

              expect(editor.lineTextForBufferRow(0)).toBe "var quicksort = function () {  var sort = function(items) {    if (items.length <= 1) return items;"

              [cursor1, cursor2] = editor.getCursors()
              expect(cursor1.getBufferPosition()).toEqual [0,29]
              expect(cursor2.getBufferPosition()).toEqual [0,59]

      describe "when there is a single selection", ->
        it "deletes the selection, but not the character following it", ->
          editor.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
          editor.delete()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
          expect(buffer.lineForRow(2)).toBe 'if (items.length <= 1) return items;'
          expect(editor.getLastSelection().isEmpty()).toBeTruthy()

      describe "when there are multiple selections", ->
        describe "when selections are on the same line", ->
          it "removes all selected text", ->
            editor.setSelectedBufferRanges([[[0,4], [0,13]], [[0,16], [0,24]]])
            editor.delete()
            expect(editor.lineTextForBufferRow(0)).toBe 'var  =  () {'

    describe ".deleteToEndOfWord()", ->
      describe "when no text is selected", ->
        it "deletes to the end of the word", ->
          editor.setCursorBufferPosition([1, 24])
          editor.addCursorAtBufferPosition([2, 5])
          [cursor1, cursor2] = editor.getCursors()

          editor.deleteToEndOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
          expect(buffer.lineForRow(2)).toBe '    i (items.length <= 1) return items;'
          expect(cursor1.getBufferPosition()).toEqual [1, 24]
          expect(cursor2.getBufferPosition()).toEqual [2, 5]

          editor.deleteToEndOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it {'
          expect(buffer.lineForRow(2)).toBe '    iitems.length <= 1) return items;'
          expect(cursor1.getBufferPosition()).toEqual [1, 24]
          expect(cursor2.getBufferPosition()).toEqual [2, 5]

      describe "when text is selected", ->
        it "deletes only selected text", ->
          editor.setSelectedBufferRange([[1, 24], [1, 27]])
          editor.deleteToEndOfWord()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'

    describe ".indent()", ->
      describe "when the selection is empty", ->
        describe "when autoIndent is disabled", ->
          describe "if 'softTabs' is true (the default)", ->
            it "inserts 'tabLength' spaces into the buffer", ->
              tabRegex = new RegExp("^[ ]{#{editor.getTabLength()}}")
              expect(buffer.lineForRow(0)).not.toMatch(tabRegex)
              editor.indent()
              expect(buffer.lineForRow(0)).toMatch(tabRegex)

            it "respects the tab stops when cursor is in the middle of a tab", ->
              editor.setTabLength(4)
              buffer.insert([12, 2], "\n ")
              editor.setCursorBufferPosition [13, 1]
              editor.indent()
              expect(buffer.lineForRow(13)).toMatch /^\s+$/
              expect(buffer.lineForRow(13).length).toBe 4
              expect(editor.getCursorBufferPosition()).toEqual [13, 4]

              buffer.insert([13, 0], "  ")
              editor.setCursorBufferPosition [13, 6]
              editor.indent()
              expect(buffer.lineForRow(13).length).toBe 8

          describe "if 'softTabs' is false", ->
            it "insert a \t into the buffer", ->
              editor.setSoftTabs(false)
              expect(buffer.lineForRow(0)).not.toMatch(/^\t/)
              editor.indent()
              expect(buffer.lineForRow(0)).toMatch(/^\t/)

        describe "when autoIndent is enabled", ->
          describe "when the cursor's column is less than the suggested level of indentation", ->
            describe "when 'softTabs' is true (the default)", ->
              it "moves the cursor to the end of the leading whitespace and inserts enough whitespace to bring the line to the suggested level of indentaion", ->
                buffer.insert([5, 0], "  \n")
                editor.setCursorBufferPosition [5, 0]
                editor.indent(autoIndent: true)
                expect(buffer.lineForRow(5)).toMatch /^\s+$/
                expect(buffer.lineForRow(5).length).toBe 6
                expect(editor.getCursorBufferPosition()).toEqual [5, 6]

              it "respects the tab stops when cursor is in the middle of a tab", ->
                editor.setTabLength(4)
                buffer.insert([12, 2], "\n ")
                editor.setCursorBufferPosition [13, 1]
                editor.indent(autoIndent: true)
                expect(buffer.lineForRow(13)).toMatch /^\s+$/
                expect(buffer.lineForRow(13).length).toBe 4
                expect(editor.getCursorBufferPosition()).toEqual [13, 4]

                buffer.insert([13, 0], "  ")
                editor.setCursorBufferPosition [13, 6]
                editor.indent(autoIndent: true)
                expect(buffer.lineForRow(13).length).toBe 8

            describe "when 'softTabs' is false", ->
              it "moves the cursor to the end of the leading whitespace and inserts enough tabs to bring the line to the suggested level of indentaion", ->
                convertToHardTabs(buffer)
                editor.setSoftTabs(false)
                buffer.insert([5, 0], "\t\n")
                editor.setCursorBufferPosition [5, 0]
                editor.indent(autoIndent: true)
                expect(buffer.lineForRow(5)).toMatch /^\t\t\t$/
                expect(editor.getCursorBufferPosition()).toEqual [5, 3]

              describe "when the difference between the suggested level of indentation and the current level of indentation is greater than 0 but less than 1", ->
                it "inserts one tab", ->
                  editor.setSoftTabs(false)
                  buffer.setText(" \ntest")
                  editor.setCursorBufferPosition [1, 0]

                  editor.indent(autoIndent: true)
                  expect(buffer.lineForRow(1)).toBe '\ttest'
                  expect(editor.getCursorBufferPosition()).toEqual [1, 1]

          describe "when the line's indent level is greater than the suggested level of indentation", ->
            describe "when 'softTabs' is true (the default)", ->
              it "moves the cursor to the end of the leading whitespace and inserts 'tabLength' spaces into the buffer", ->
                buffer.insert([7, 0], "      \n")
                editor.setCursorBufferPosition [7, 2]
                editor.indent(autoIndent: true)
                expect(buffer.lineForRow(7)).toMatch /^\s+$/
                expect(buffer.lineForRow(7).length).toBe 8
                expect(editor.getCursorBufferPosition()).toEqual [7, 8]

            describe "when 'softTabs' is false", ->
              it "moves the cursor to the end of the leading whitespace and inserts \t into the buffer", ->
                convertToHardTabs(buffer)
                editor.setSoftTabs(false)
                buffer.insert([7, 0], "\t\t\t\n")
                editor.setCursorBufferPosition [7, 1]
                editor.indent(autoIndent: true)
                expect(buffer.lineForRow(7)).toMatch /^\t\t\t\t$/
                expect(editor.getCursorBufferPosition()).toEqual [7, 4]

      describe "when the selection is not empty", ->
        it "indents the selected lines", ->
          editor.setSelectedBufferRange([[0, 0], [10, 0]])
          selection = editor.getLastSelection()
          spyOn(selection, "indentSelectedRows")
          editor.indent()
          expect(selection.indentSelectedRows).toHaveBeenCalled()

      describe "if editor.softTabs is false", ->
        it "inserts a tab character into the buffer", ->
          editor.setSoftTabs(false)
          expect(buffer.lineForRow(0)).not.toMatch(/^\t/)
          editor.indent()
          expect(buffer.lineForRow(0)).toMatch(/^\t/)
          expect(editor.getCursorBufferPosition()).toEqual [0, 1]
          expect(editor.getCursorScreenPosition()).toEqual [0, editor.getTabLength()]

          editor.indent()
          expect(buffer.lineForRow(0)).toMatch(/^\t\t/)
          expect(editor.getCursorBufferPosition()).toEqual [0, 2]
          expect(editor.getCursorScreenPosition()).toEqual [0, editor.getTabLength() * 2]

    describe "clipboard operations", ->
      describe ".cutSelectedText()", ->
        it "removes the selected text from the buffer and places it on the clipboard", ->
          editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]])
          editor.cutSelectedText()
          expect(buffer.lineForRow(0)).toBe "var  = function () {"
          expect(buffer.lineForRow(1)).toBe "  var  = function(items) {"
          expect(clipboard.readText()).toBe 'quicksort\nsort'

        describe "when no text is selected", ->
          beforeEach ->
            editor.setSelectedBufferRanges([
              [[0, 0], [0, 0]],
              [[5, 0], [5, 0]],
            ])

          it "cuts the lines on which there are cursors", ->
            editor.cutSelectedText()
            expect(buffer.getLineCount()).toBe(11)
            expect(buffer.lineForRow(1)).toBe("    if (items.length <= 1) return items;")
            expect(buffer.lineForRow(4)).toBe("      current < pivot ? left.push(current) : right.push(current);")
            expect(atom.clipboard.read()).toEqual """
              var quicksort = function () {

                    current = items.shift();

            """

        describe "when many selections get added in shuffle order", ->
          it "cuts them in order", ->
            editor.setSelectedBufferRanges([
              [[2,8], [2, 13]]
              [[0,4], [0,13]],
              [[1,6], [1, 10]],
            ])
            editor.cutSelectedText()
            expect(atom.clipboard.read()).toEqual """
              quicksort
              sort
              items
            """

      describe ".cutToEndOfLine()", ->
        describe "when soft wrap is on", ->
          it "cuts up to the end of the line", ->
            editor.setSoftWrapped(true)
            editor.setEditorWidthInChars(10)
            editor.setCursorScreenPosition([2, 2])
            editor.cutToEndOfLine()
            expect(editor.tokenizedLineForScreenRow(2).text).toBe '=  () {'

        describe "when soft wrap is off", ->
          describe "when nothing is selected", ->
            it "cuts up to the end of the line", ->
              editor.setCursorBufferPosition([2, 20])
              editor.addCursorAtBufferPosition([3, 20])
              editor.cutToEndOfLine()
              expect(buffer.lineForRow(2)).toBe '    if (items.length'
              expect(buffer.lineForRow(3)).toBe '    var pivot = item'
              expect(atom.clipboard.read()).toBe ' <= 1) return items;\ns.shift(), current, left = [], right = [];'

          describe "when text is selected", ->
            it "only cuts the selected text, not to the end of the line", ->
              editor.setSelectedBufferRanges([[[2,20], [2, 30]], [[3, 20], [3, 20]]])

              editor.cutToEndOfLine()

              expect(buffer.lineForRow(2)).toBe '    if (items.lengthurn items;'
              expect(buffer.lineForRow(3)).toBe '    var pivot = item'
              expect(atom.clipboard.read()).toBe ' <= 1) ret\ns.shift(), current, left = [], right = [];'

      describe ".copySelectedText()", ->
        it "copies selected text onto the clipboard", ->
          editor.setSelectedBufferRanges([[[0,4], [0,13]], [[1,6], [1, 10]], [[2,8], [2, 13]]])

          editor.copySelectedText()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
          expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"
          expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(clipboard.readText()).toBe 'quicksort\nsort\nitems'
          expect(atom.clipboard.read()).toEqual """
            quicksort
            sort
            items
          """

        describe "when no text is selected", ->
          beforeEach ->
            editor.setSelectedBufferRanges([
              [[1, 5], [1, 5]],
              [[5, 8], [5, 8]]
            ])

          it "copies the lines on which there are cursors", ->
            editor.copySelectedText()
            expect(atom.clipboard.read()).toEqual([
              "  var sort = function(items) {\n"
              "      current = items.shift();\n"
            ].join("\n"))
            expect(editor.getSelectedBufferRanges()).toEqual([
              [[1, 5], [1, 5]],
              [[5, 8], [5, 8]]
            ])

        describe "when many selections get added in shuffle order", ->
          it "copies them in order", ->
            editor.setSelectedBufferRanges([
              [[2,8], [2, 13]]
              [[0,4], [0,13]],
              [[1,6], [1, 10]],
            ])
            editor.copySelectedText()
            expect(atom.clipboard.read()).toEqual """
              quicksort
              sort
              items
            """

      describe ".pasteText()", ->
        copyText = (text, {startColumn, textEditor}={}) ->
          startColumn ?= 0
          textEditor ?= editor
          textEditor.setCursorBufferPosition([0, 0])
          textEditor.insertText(text)
          numberOfNewlines = text.match(/\n/g)?.length
          endColumn = text.match(/[^\n]*$/)[0]?.length
          textEditor.getLastSelection().setBufferRange([[0,startColumn], [numberOfNewlines,endColumn]])
          textEditor.cutSelectedText()

        it "pastes text into the buffer", ->
          editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]])
          atom.clipboard.write('first')
          editor.pasteText()
          expect(editor.lineTextForBufferRow(0)).toBe "var first = function () {"
          expect(editor.lineTextForBufferRow(1)).toBe "  var first = function(items) {"

        describe "when `autoIndentOnPaste` is true", ->
          beforeEach ->
            atom.config.set("editor.autoIndentOnPaste", true)

          describe "when only whitespace precedes the cursor", ->
            it "auto-indents the lines spanned by the pasted text, based on the first pasted line", ->
              expect(editor.indentationForBufferRow(5)).toBe(3)

              atom.clipboard.write("a(x);\n  b(x);\n    c(x);\n", indentBasis: 0)
              editor.setCursorBufferPosition([5, 0])
              editor.pasteText()

              # Adjust the indentation of the pasted block
              expect(editor.indentationForBufferRow(5)).toBe(3)
              expect(editor.indentationForBufferRow(6)).toBe(4)
              expect(editor.indentationForBufferRow(7)).toBe(5)

              # Preserve the indentation of the next row
              expect(editor.indentationForBufferRow(8)).toBe(3)

          describe "when non-whitespace characters precede the cursor", ->
            it "does not auto-indent the first line being pasted", ->
              editor.setText """
              if (x) {
                  y();
              }
              """

              atom.clipboard.write(" z();")
              editor.setCursorBufferPosition([1, Infinity])
              editor.pasteText()
              expect(editor.lineTextForBufferRow(1)).toBe("    y(); z();")

        describe "when `autoIndentOnPaste` is false", ->
          beforeEach ->
            atom.config.set('editor.autoIndentOnPaste', false)

          describe "when the cursor is indented further than the original copied text", ->
            it "increases the indentation of the copied lines to match", ->
              editor.setSelectedBufferRange([[1, 2], [3, 0]])
              editor.copySelectedText()

              editor.setCursorBufferPosition([5, 6])
              editor.pasteText()

              expect(editor.lineTextForBufferRow(5)).toBe "      var sort = function(items) {"
              expect(editor.lineTextForBufferRow(6)).toBe "        if (items.length <= 1) return items;"

          describe "when the cursor is indented less far than the original copied text", ->
            it "decreases the indentation of the copied lines to match", ->
              editor.setSelectedBufferRange([[6, 6], [8, 0]])
              editor.copySelectedText()

              editor.setCursorBufferPosition([1, 2])
              editor.pasteText()

              expect(editor.lineTextForBufferRow(1)).toBe "  current < pivot ? left.push(current) : right.push(current);"
              expect(editor.lineTextForBufferRow(2)).toBe "}"

          describe "when the first copied line has leading whitespace", ->
            it "preserves the line's leading whitespace", ->
              editor.setSelectedBufferRange([[4, 0], [6, 0]])
              editor.copySelectedText()

              editor.setCursorBufferPosition([0, 0])
              editor.pasteText()

              expect(editor.lineTextForBufferRow(0)).toBe "    while(items.length > 0) {"
              expect(editor.lineTextForBufferRow(1)).toBe "      current = items.shift();"

        describe 'when the clipboard has many selections', ->
          beforeEach ->
            atom.config.set("editor.autoIndentOnPaste", false)
            editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]])
            editor.copySelectedText()

          it "pastes each selection in order separately into the buffer", ->
            editor.setSelectedBufferRanges([
              [[1, 6], [1, 10]]
              [[0, 4], [0, 13]],
            ])

            editor.moveRight()
            editor.insertText("_")
            editor.pasteText()
            expect(editor.lineTextForBufferRow(0)).toBe "var quicksort_quicksort = function () {"
            expect(editor.lineTextForBufferRow(1)).toBe "  var sort_sort = function(items) {"

          describe 'and the selections count does not match', ->
            beforeEach ->
              editor.setSelectedBufferRanges([[[0, 4], [0, 13]]])

            it "pastes the whole text into the buffer", ->
              editor.pasteText()
              expect(editor.lineTextForBufferRow(0)).toBe "var quicksort"
              expect(editor.lineTextForBufferRow(1)).toBe "sort = function () {"

        describe "when a full line was cut", ->
          beforeEach ->
            editor.setCursorBufferPosition([2, 13])
            editor.cutSelectedText()
            editor.setCursorBufferPosition([2, 13])

          it "pastes the line above the cursor and retains the cursor's column", ->
            editor.pasteText()
            expect(editor.lineTextForBufferRow(2)).toBe("    if (items.length <= 1) return items;")
            expect(editor.lineTextForBufferRow(3)).toBe("    var pivot = items.shift(), current, left = [], right = [];")
            expect(editor.getCursorBufferPosition()).toEqual([3, 13])

        describe "when a full line was copied", ->
          beforeEach ->
            editor.setCursorBufferPosition([2, 13])
            editor.copySelectedText()

          describe "when there is a selection", ->
            it "overwrites the selection as with any copied text", ->
              editor.setSelectedBufferRange([[1, 2], [1, Infinity]])
              editor.pasteText()
              expect(editor.lineTextForBufferRow(1)).toBe("  if (items.length <= 1) return items;")
              expect(editor.lineTextForBufferRow(2)).toBe("")
              expect(editor.lineTextForBufferRow(3)).toBe("    if (items.length <= 1) return items;")
              expect(editor.getCursorBufferPosition()).toEqual([2, 0])

          describe "when there is no selection", ->
            it "pastes the line above the cursor and retains the cursor's column", ->
              editor.pasteText()
              expect(editor.lineTextForBufferRow(2)).toBe("    if (items.length <= 1) return items;")
              expect(editor.lineTextForBufferRow(3)).toBe("    if (items.length <= 1) return items;")
              expect(editor.getCursorBufferPosition()).toEqual([3, 13])

    describe ".indentSelectedRows()", ->
      describe "when nothing is selected", ->
        describe "when softTabs is enabled", ->
          it "indents line and retains selection", ->
            editor.setSelectedBufferRange([[0,3], [0,3]])
            editor.indentSelectedRows()
            expect(buffer.lineForRow(0)).toBe "  var quicksort = function () {"
            expect(editor.getSelectedBufferRange()).toEqual [[0, 3 + editor.getTabLength()], [0, 3 + editor.getTabLength()]]

        describe "when softTabs is disabled", ->
          it "indents line and retains selection", ->
            convertToHardTabs(buffer)
            editor.setSoftTabs(false)
            editor.setSelectedBufferRange([[0,3], [0,3]])
            editor.indentSelectedRows()
            expect(buffer.lineForRow(0)).toBe "\tvar quicksort = function () {"
            expect(editor.getSelectedBufferRange()).toEqual [[0, 3 + 1], [0, 3 + 1]]

      describe "when one line is selected", ->
        describe "when softTabs is enabled", ->
          it "indents line and retains selection", ->
            editor.setSelectedBufferRange([[0,4], [0,14]])
            editor.indentSelectedRows()
            expect(buffer.lineForRow(0)).toBe "#{editor.getTabText()}var quicksort = function () {"
            expect(editor.getSelectedBufferRange()).toEqual [[0, 4 + editor.getTabLength()], [0, 14 + editor.getTabLength()]]

        describe "when softTabs is disabled", ->
          it "indents line and retains selection", ->
            convertToHardTabs(buffer)
            editor.setSoftTabs(false)
            editor.setSelectedBufferRange([[0,4], [0,14]])
            editor.indentSelectedRows()
            expect(buffer.lineForRow(0)).toBe "\tvar quicksort = function () {"
            expect(editor.getSelectedBufferRange()).toEqual [[0, 4 + 1], [0, 14 + 1]]

      describe "when multiple lines are selected", ->
        describe "when softTabs is enabled", ->
          it "indents selected lines (that are not empty) and retains selection", ->
            editor.setSelectedBufferRange([[9,1], [11,15]])
            editor.indentSelectedRows()
            expect(buffer.lineForRow(9)).toBe "    };"
            expect(buffer.lineForRow(10)).toBe ""
            expect(buffer.lineForRow(11)).toBe "    return sort(Array.apply(this, arguments));"
            expect(editor.getSelectedBufferRange()).toEqual [[9, 1 + editor.getTabLength()], [11, 15 + editor.getTabLength()]]

          it "does not indent the last row if the selection ends at column 0", ->
            editor.setSelectedBufferRange([[9,1], [11,0]])
            editor.indentSelectedRows()
            expect(buffer.lineForRow(9)).toBe "    };"
            expect(buffer.lineForRow(10)).toBe ""
            expect(buffer.lineForRow(11)).toBe "  return sort(Array.apply(this, arguments));"
            expect(editor.getSelectedBufferRange()).toEqual [[9, 1 + editor.getTabLength()], [11, 0]]

        describe "when softTabs is disabled", ->
          it "indents selected lines (that are not empty) and retains selection", ->
            convertToHardTabs(buffer)
            editor.setSoftTabs(false)
            editor.setSelectedBufferRange([[9,1], [11,15]])
            editor.indentSelectedRows()
            expect(buffer.lineForRow(9)).toBe "\t\t};"
            expect(buffer.lineForRow(10)).toBe ""
            expect(buffer.lineForRow(11)).toBe "\t\treturn sort(Array.apply(this, arguments));"
            expect(editor.getSelectedBufferRange()).toEqual [[9, 1 + 1], [11, 15 + 1]]

    describe ".outdentSelectedRows()", ->
      describe "when nothing is selected", ->
        it "outdents line and retains selection", ->
          editor.setSelectedBufferRange([[1,3], [1,3]])
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
          expect(editor.getSelectedBufferRange()).toEqual [[1, 3 - editor.getTabLength()], [1, 3 - editor.getTabLength()]]

        it "outdents when indent is less than a tab length", ->
          editor.insertText(' ')
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

        it "outdents a single hard tab when indent is multiple hard tabs and and the session is using soft tabs", ->
          editor.insertText('\t\t')
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "\tvar quicksort = function () {"
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

        it "outdents when a mix of hard tabs and soft tabs are used", ->
          editor.insertText('\t   ')
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "   var quicksort = function () {"
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe " var quicksort = function () {"
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

        it "outdents only up to the first non-space non-tab character", ->
          editor.insertText(' \tfoo\t ')
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "\tfoo\t var quicksort = function () {"
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "foo\t var quicksort = function () {"
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "foo\t var quicksort = function () {"

      describe "when one line is selected", ->
        it "outdents line and retains editor", ->
          editor.setSelectedBufferRange([[1,4], [1,14]])
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
          expect(editor.getSelectedBufferRange()).toEqual [[1, 4 - editor.getTabLength()], [1, 14 - editor.getTabLength()]]

      describe "when multiple lines are selected", ->
        it "outdents selected lines and retains editor", ->
          editor.setSelectedBufferRange([[0,1], [3,15]])
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
          expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
          expect(buffer.lineForRow(2)).toBe "  if (items.length <= 1) return items;"
          expect(buffer.lineForRow(3)).toBe "  var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [3, 15 - editor.getTabLength()]]

        it "does not outdent the last line of the selection if it ends at column 0", ->
          editor.setSelectedBufferRange([[0,1], [3,0]])
          editor.outdentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
          expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
          expect(buffer.lineForRow(2)).toBe "  if (items.length <= 1) return items;"
          expect(buffer.lineForRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [3, 0]]

    describe ".autoIndentSelectedRows", ->
      it "auto-indents the selection", ->
        editor.setCursorBufferPosition([2, 0])
        editor.insertText("function() {\ninside=true\n}\n  i=1\n")
        editor.getLastSelection().setBufferRange([[2,0], [6,0]])
        editor.autoIndentSelectedRows()

        expect(editor.lineTextForBufferRow(2)).toBe "    function() {"
        expect(editor.lineTextForBufferRow(3)).toBe "      inside=true"
        expect(editor.lineTextForBufferRow(4)).toBe "    }"
        expect(editor.lineTextForBufferRow(5)).toBe "    i=1"

    describe ".toggleLineCommentsInSelection()", ->
      it "toggles comments on the selected lines", ->
        editor.setSelectedBufferRange([[4, 5], [7, 5]])
        editor.toggleLineCommentsInSelection()

        expect(buffer.lineForRow(4)).toBe "    // while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "    //   current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "    //   current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "    // }"
        expect(editor.getSelectedBufferRange()).toEqual [[4, 8], [7, 8]]

        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "      current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "    }"

      it "does not comment the last line of a non-empty selection if it ends at column 0", ->
        editor.setSelectedBufferRange([[4, 5], [7, 0]])
        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(4)).toBe "    // while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "    //   current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "    //   current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "    }"

      it "uncomments lines if all lines match the comment regex", ->
        editor.setSelectedBufferRange([[0, 0], [0, 1]])
        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(0)).toBe "// var quicksort = function () {"

        editor.setSelectedBufferRange([[0, 0], [2, Infinity]])
        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(0)).toBe "// // var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe "//   var sort = function(items) {"
        expect(buffer.lineForRow(2)).toBe "//     if (items.length <= 1) return items;"

        editor.setSelectedBufferRange([[0, 0], [2, Infinity]])
        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(0)).toBe "// var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"
        expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"

        editor.setSelectedBufferRange([[0, 0], [0, Infinity]])
        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

      it "uncomments commented lines separated by an empty line", ->
        editor.setSelectedBufferRange([[0, 0], [1, Infinity]])
        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(0)).toBe "// var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe "//   var sort = function(items) {"

        buffer.insert([0, Infinity], '\n')

        editor.setSelectedBufferRange([[0, 0], [2, Infinity]])
        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe ""
        expect(buffer.lineForRow(2)).toBe "  var sort = function(items) {"

      it "preserves selection emptiness", ->
        editor.setCursorBufferPosition([4, 0])
        editor.toggleLineCommentsInSelection()
        expect(editor.getLastSelection().isEmpty()).toBeTruthy()

      it "does not explode if the current language mode has no comment regex", ->
        editor.destroy()

        waitsForPromise ->
          atom.workspace.open(null, autoIndent: false).then (o) -> editor = o

        runs ->
          editor.setSelectedBufferRange([[4, 5], [4, 5]])
          editor.toggleLineCommentsInSelection()
          expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"

      it "uncomments when the line lacks the trailing whitespace in the comment regex", ->
        editor.setCursorBufferPosition([10, 0])
        editor.toggleLineCommentsInSelection()

        expect(buffer.lineForRow(10)).toBe "// "
        expect(editor.getSelectedBufferRange()).toEqual [[10, 3], [10, 3]]
        editor.backspace()
        expect(buffer.lineForRow(10)).toBe "//"

        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(10)).toBe ""
        expect(editor.getSelectedBufferRange()).toEqual [[10, 0], [10, 0]]

      it "uncomments when the line has leading whitespace", ->
        editor.setCursorBufferPosition([10, 0])
        editor.toggleLineCommentsInSelection()

        expect(buffer.lineForRow(10)).toBe "// "
        editor.moveToBeginningOfLine()
        editor.insertText("  ")
        editor.setSelectedBufferRange([[10, 0], [10, 0]])
        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(10)).toBe "  "

    describe ".undo() and .redo()", ->
      it "undoes/redoes the last change", ->
        editor.insertText("foo")
        editor.undo()
        expect(buffer.lineForRow(0)).not.toContain "foo"

        editor.redo()
        expect(buffer.lineForRow(0)).toContain "foo"

      it "batches the undo / redo of changes caused by multiple cursors", ->
        editor.setCursorScreenPosition([0, 0])
        editor.addCursorAtScreenPosition([1, 0])

        editor.insertText("foo")
        editor.backspace()

        expect(buffer.lineForRow(0)).toContain "fovar"
        expect(buffer.lineForRow(1)).toContain "fo "

        editor.undo()

        expect(buffer.lineForRow(0)).toContain "foo"
        expect(buffer.lineForRow(1)).toContain "foo"

        editor.redo()

        expect(buffer.lineForRow(0)).not.toContain "foo"
        expect(buffer.lineForRow(0)).toContain "fovar"

      it "restores the selected ranges after undo and redo", ->
        editor.setSelectedBufferRanges([[[1, 6], [1, 10]], [[1, 22], [1, 27]]])
        editor.delete()
        editor.delete()

        selections = editor.getSelections()
        expect(buffer.lineForRow(1)).toBe '  var = function( {'

        expect(editor.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 6]], [[1, 17], [1, 17]]]

        editor.undo()
        expect(editor.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 6]], [[1, 18], [1, 18]]]

        editor.undo()
        expect(editor.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 10]], [[1, 22], [1, 27]]]

        editor.redo()
        expect(editor.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 6]], [[1, 18], [1, 18]]]

      xit "restores folds after undo and redo", ->
        editor.foldBufferRow(1)
        editor.setSelectedBufferRange([[1, 0], [10, Infinity]], preserveFolds: true)
        expect(editor.isFoldedAtBufferRow(1)).toBeTruthy()

        editor.insertText """
          \  // testing
            function foo() {
              return 1 + 2;
            }
        """
        expect(editor.isFoldedAtBufferRow(1)).toBeFalsy()
        editor.foldBufferRow(2)

        editor.undo()
        expect(editor.isFoldedAtBufferRow(1)).toBeTruthy()
        expect(editor.isFoldedAtBufferRow(9)).toBeTruthy()
        expect(editor.isFoldedAtBufferRow(10)).toBeFalsy()

        editor.redo()
        expect(editor.isFoldedAtBufferRow(1)).toBeFalsy()
        expect(editor.isFoldedAtBufferRow(2)).toBeTruthy()

    describe "::transact", ->
      it "restores the selection when the transaction is undone/redone", ->
        buffer.setText('1234')
        editor.setSelectedBufferRange([[0, 1], [0, 3]])

        editor.transact ->
          editor.delete()
          editor.moveToEndOfLine()
          editor.insertText('5')
          expect(buffer.getText()).toBe '145'

        editor.undo()
        expect(buffer.getText()).toBe '1234'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 3]]

        editor.redo()
        expect(buffer.getText()).toBe '145'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 3], [0, 3]]

    describe "when the buffer is changed (via its direct api, rather than via than edit session)", ->
      it "moves the cursor so it is in the same relative position of the buffer", ->
        expect(editor.getCursorScreenPosition()).toEqual [0, 0]
        editor.addCursorAtScreenPosition([0, 5])
        editor.addCursorAtScreenPosition([1, 0])
        [cursor1, cursor2, cursor3] = editor.getCursors()

        buffer.insert([0, 1], 'abc')

        expect(cursor1.getScreenPosition()).toEqual [0, 0]
        expect(cursor2.getScreenPosition()).toEqual [0, 8]
        expect(cursor3.getScreenPosition()).toEqual [1, 0]

      it "does not destroy cursors or selections when a change encompasses them", ->
        cursor = editor.getLastCursor()
        cursor.setBufferPosition [3, 3]
        editor.buffer.delete([[3, 1], [3, 5]])
        expect(cursor.getBufferPosition()).toEqual [3, 1]
        expect(editor.getCursors().indexOf(cursor)).not.toBe -1

        selection = editor.getLastSelection()
        selection.setBufferRange [[3, 5], [3, 10]]
        editor.buffer.delete [[3, 3], [3, 8]]
        expect(selection.getBufferRange()).toEqual [[3, 3], [3, 5]]
        expect(editor.getSelections().indexOf(selection)).not.toBe -1

      it "merges cursors when the change causes them to overlap", ->
        editor.setCursorScreenPosition([0, 0])
        editor.addCursorAtScreenPosition([0, 2])
        editor.addCursorAtScreenPosition([1, 2])

        [cursor1, cursor2, cursor3] = editor.getCursors()
        expect(editor.getCursors().length).toBe 3

        buffer.delete([[0, 0], [0, 2]])

        expect(editor.getCursors().length).toBe 2
        expect(editor.getCursors()).toEqual [cursor1, cursor3]
        expect(cursor1.getBufferPosition()).toEqual [0,0]
        expect(cursor3.getBufferPosition()).toEqual [1,2]

  describe 'reading text', ->
    it '.lineTextForScreenRow(row)', ->
      editor.foldBufferRow(4)
      expect(editor.lineTextForScreenRow(5)).toEqual '    return sort(left).concat(pivot).concat(sort(right));'
      expect(editor.lineTextForScreenRow(100)).not.toBeDefined()

  describe ".deleteLine()", ->
    it "deletes the first line when the cursor is there", ->
      editor.getLastCursor().moveToTop()
      line1 = buffer.lineForRow(1)
      count = buffer.getLineCount()
      expect(buffer.lineForRow(0)).not.toBe(line1)
      editor.deleteLine()
      expect(buffer.lineForRow(0)).toBe(line1)
      expect(buffer.getLineCount()).toBe(count - 1)

    it "deletes the last line when the cursor is there", ->
      count = buffer.getLineCount()
      secondToLastLine = buffer.lineForRow(count - 2)
      expect(buffer.lineForRow(count - 1)).not.toBe(secondToLastLine)
      editor.getLastCursor().moveToBottom()
      editor.deleteLine()
      newCount = buffer.getLineCount()
      expect(buffer.lineForRow(newCount - 1)).toBe(secondToLastLine)
      expect(newCount).toBe(count - 1)

    it "deletes whole lines when partial lines are selected", ->
      editor.setSelectedBufferRange([[0, 2], [1, 2]])
      line2 = buffer.lineForRow(2)
      count = buffer.getLineCount()
      expect(buffer.lineForRow(0)).not.toBe(line2)
      expect(buffer.lineForRow(1)).not.toBe(line2)
      editor.deleteLine()
      expect(buffer.lineForRow(0)).toBe(line2)
      expect(buffer.getLineCount()).toBe(count - 2)

    it "deletes a line only once when multiple selections are on the same line", ->
      line1 = buffer.lineForRow(1)
      count = buffer.getLineCount()
      editor.setSelectedBufferRanges([
        [[0, 1], [0, 2]],
        [[0, 4], [0, 5]]
      ])
      expect(buffer.lineForRow(0)).not.toBe(line1)

      editor.deleteLine()

      expect(buffer.lineForRow(0)).toBe(line1)
      expect(buffer.getLineCount()).toBe(count - 1)

    it "only deletes first line if only newline is selected on second line", ->
      editor.setSelectedBufferRange([[0, 2], [1, 0]])
      line1 = buffer.lineForRow(1)
      count = buffer.getLineCount()
      expect(buffer.lineForRow(0)).not.toBe(line1)
      editor.deleteLine()
      expect(buffer.lineForRow(0)).toBe(line1)
      expect(buffer.getLineCount()).toBe(count - 1)

    it "deletes the entire region when invoke on a folded region", ->
      editor.foldBufferRow(1)
      editor.getLastCursor().moveToTop()
      editor.getLastCursor().moveDown()
      expect(buffer.getLineCount()).toBe(13)
      editor.deleteLine()
      expect(buffer.getLineCount()).toBe(4)

    it "deletes the entire file from the bottom up", ->
      count = buffer.getLineCount()
      expect(count).toBeGreaterThan(0)
      for line in [0...count]
        editor.getLastCursor().moveToBottom()
        editor.deleteLine()
      expect(buffer.getLineCount()).toBe(1)
      expect(buffer.getText()).toBe('')

    it "deletes the entire file from the top down", ->
      count = buffer.getLineCount()
      expect(count).toBeGreaterThan(0)
      for line in [0...count]
        editor.getLastCursor().moveToTop()
        editor.deleteLine()
      expect(buffer.getLineCount()).toBe(1)
      expect(buffer.getText()).toBe('')

    describe "when soft wrap is enabled", ->
      it "deletes the entire line that the cursor is on", ->
        editor.setSoftWrapped(true)
        editor.setEditorWidthInChars(10)
        editor.setCursorBufferPosition([6])

        line7 = buffer.lineForRow(7)
        count = buffer.getLineCount()
        expect(buffer.lineForRow(6)).not.toBe(line7)
        editor.deleteLine()
        expect(buffer.lineForRow(6)).toBe(line7)
        expect(buffer.getLineCount()).toBe(count - 1)

    describe "when the line being deleted preceeds a fold, and the command is undone", ->
      it "restores the line and preserves the fold", ->
        editor.setCursorBufferPosition([4])
        editor.foldCurrentRow()
        expect(editor.isFoldedAtScreenRow(4)).toBeTruthy()
        editor.setCursorBufferPosition([3])
        editor.deleteLine()
        expect(editor.isFoldedAtScreenRow(3)).toBeTruthy()
        expect(buffer.lineForRow(3)).toBe '    while(items.length > 0) {'
        editor.undo()
        expect(editor.isFoldedAtScreenRow(4)).toBeTruthy()
        expect(buffer.lineForRow(3)).toBe '    var pivot = items.shift(), current, left = [], right = [];'

  describe ".replaceSelectedText(options, fn)", ->
    describe "when no text is selected", ->
      it "inserts the text returned from the function at the cursor position", ->
        editor.replaceSelectedText {}, -> '123'
        expect(buffer.lineForRow(0)).toBe '123var quicksort = function () {'

        editor.replaceSelectedText {selectWordIfEmpty: true}, -> 'var'
        editor.setCursorBufferPosition([0])
        expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {'

        editor.setCursorBufferPosition([10])
        editor.replaceSelectedText null, -> ''
        expect(buffer.lineForRow(10)).toBe ''

    describe "when text is selected", ->
      it "replaces the selected text with the text returned from the function", ->
        editor.setSelectedBufferRange([[0, 1], [0, 3]])
        editor.replaceSelectedText {}, -> 'ia'
        expect(buffer.lineForRow(0)).toBe 'via quicksort = function () {'

  describe ".transpose()", ->
    it "swaps two characters", ->
      editor.buffer.setText("abc")
      editor.setCursorScreenPosition([0, 1])
      editor.transpose()
      expect(editor.lineTextForBufferRow(0)).toBe 'bac'

    it "reverses a selection", ->
      editor.buffer.setText("xabcz")
      editor.setSelectedBufferRange([[0, 1], [0, 4]])
      editor.transpose()
      expect(editor.lineTextForBufferRow(0)).toBe 'xcbaz'

  describe ".upperCase()", ->
    describe "when there is no selection", ->
      it "upper cases the current word", ->
        editor.buffer.setText("aBc")
        editor.setCursorScreenPosition([0, 1])
        editor.upperCase()
        expect(editor.lineTextForBufferRow(0)).toBe 'ABC'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 1]]

    describe "when there is a selection", ->
      it "upper cases the current selection", ->
        editor.buffer.setText("abc")
        editor.setSelectedBufferRange([[0,0], [0,2]])
        editor.upperCase()
        expect(editor.lineTextForBufferRow(0)).toBe 'ABc'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 2]]

  describe ".lowerCase()", ->
    describe "when there is no selection", ->
      it "lower cases the current word", ->
        editor.buffer.setText("aBC")
        editor.setCursorScreenPosition([0, 1])
        editor.lowerCase()
        expect(editor.lineTextForBufferRow(0)).toBe 'abc'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 1]]

    describe "when there is a selection", ->
      it "lower cases the current selection", ->
        editor.buffer.setText("ABC")
        editor.setSelectedBufferRange([[0,0], [0,2]])
        editor.lowerCase()
        expect(editor.lineTextForBufferRow(0)).toBe 'abC'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 2]]

  describe "soft-tabs detection", ->
    it "assigns soft / hard tabs based on the contents of the buffer, or uses the default if unknown", ->
      waitsForPromise ->
        atom.workspace.open('sample.js', softTabs: false).then (editor) ->
          expect(editor.getSoftTabs()).toBeTruthy()

      waitsForPromise ->
        atom.workspace.open('sample-with-tabs.coffee', softTabs: true).then (editor) ->
          expect(editor.getSoftTabs()).toBeFalsy()

      waitsForPromise ->
        atom.workspace.open('sample-with-tabs-and-initial-comment.js', softTabs: true).then (editor) ->
          expect(editor.getSoftTabs()).toBeFalsy()

      waitsForPromise ->
        atom.workspace.open(null, softTabs: false).then (editor) ->
          expect(editor.getSoftTabs()).toBeFalsy()

  describe '.getTabLength()', ->
    describe 'when scoped settings are used', ->
      coffeeEditor = null
      beforeEach ->
        waitsForPromise ->
          atom.packages.activatePackage('language-coffee-script')
        waitsForPromise ->
          atom.project.open('coffee.coffee', autoIndent: false).then (o) -> coffeeEditor = o

      afterEach: ->
        atom.packages.deactivatePackages()
        atom.packages.unloadPackages()

      it 'returns correct values based on the scope of the set grammars', ->
        atom.config.set 'editor.tabLength', 6, scopeSelector: '.source.coffee'

        expect(editor.getTabLength()).toBe 2
        expect(coffeeEditor.getTabLength()).toBe 6

      it 'retokenizes when the tab length is updated via .setTabLength()', ->
        expect(editor.getTabLength()).toBe 2
        expect(editor.tokenizedLineForScreenRow(5).tokens[0].firstNonWhitespaceIndex).toBe 2

        editor.setTabLength(6)
        expect(editor.getTabLength()).toBe 6
        expect(editor.tokenizedLineForScreenRow(5).tokens[0].firstNonWhitespaceIndex).toBe 6

        changeHandler = jasmine.createSpy('changeHandler')
        editor.onDidChange(changeHandler)
        editor.setTabLength(6)
        expect(changeHandler).not.toHaveBeenCalled()

      it 'retokenizes when the editor.tabLength setting is updated', ->
        expect(editor.getTabLength()).toBe 2
        expect(editor.tokenizedLineForScreenRow(5).tokens[0].firstNonWhitespaceIndex).toBe 2

        atom.config.set 'editor.tabLength', 6, scopeSelector: '.source.js'
        expect(editor.getTabLength()).toBe 6
        expect(editor.tokenizedLineForScreenRow(5).tokens[0].firstNonWhitespaceIndex).toBe 6

      it 'updates the tab length when the grammar changes', ->
        atom.config.set 'editor.tabLength', 6, scopeSelector: '.source.coffee'

        expect(editor.getTabLength()).toBe 2
        expect(editor.tokenizedLineForScreenRow(5).tokens[0].firstNonWhitespaceIndex).toBe 2

        editor.setGrammar(coffeeEditor.getGrammar())
        expect(editor.getTabLength()).toBe 6
        expect(editor.tokenizedLineForScreenRow(5).tokens[0].firstNonWhitespaceIndex).toBe 6

  describe ".indentLevelForLine(line)", ->
    it "returns the indent level when the line has only leading whitespace", ->
      expect(editor.indentLevelForLine("    hello")).toBe(2)
      expect(editor.indentLevelForLine("   hello")).toBe(1.5)

    it "returns the indent level when the line has only leading tabs", ->
      expect(editor.indentLevelForLine("\t\thello")).toBe(2)

    it "returns the indent level when the line has mixed leading whitespace and tabs", ->
      expect(editor.indentLevelForLine("\t  hello")).toBe(2)
      expect(editor.indentLevelForLine("  \thello")).toBe(2)
      expect(editor.indentLevelForLine("  \t hello")).toBe(2.5)
      expect(editor.indentLevelForLine("  \t \thello")).toBe(3.5)

  describe "when the buffer is reloaded", ->
    it "preserves the current cursor position", ->
      editor.setCursorScreenPosition([0, 1])
      editor.buffer.reload()
      expect(editor.getCursorScreenPosition()).toEqual [0,1]

  describe "when a better-matched grammar is added to syntax", ->
    it "switches to the better-matched grammar and re-tokenizes the buffer", ->
      editor.destroy()

      jsGrammar = atom.grammars.selectGrammar('a.js')
      atom.grammars.removeGrammar(jsGrammar)

      waitsForPromise ->
        atom.workspace.open('sample.js', autoIndent: false).then (o) -> editor = o

      runs ->
        expect(editor.getGrammar()).toBe atom.grammars.nullGrammar
        expect(editor.tokenizedLineForScreenRow(0).tokens.length).toBe 1

        atom.grammars.addGrammar(jsGrammar)
        expect(editor.getGrammar()).toBe jsGrammar
        expect(editor.tokenizedLineForScreenRow(0).tokens.length).toBeGreaterThan 1

  describe "editor.autoIndent", ->
    describe "when editor.autoIndent is false (default)", ->
      describe "when `indent` is triggered", ->
        it "does not auto-indent the line", ->
          editor.setCursorBufferPosition([1, 30])
          editor.insertText("\n ")
          expect(editor.lineTextForBufferRow(2)).toBe " "

          atom.config.set("editor.autoIndent", false)
          editor.indent()
          expect(editor.lineTextForBufferRow(2)).toBe "  "

    describe "when editor.autoIndent is true", ->
      beforeEach ->
        atom.config.set("editor.autoIndent", true)

      describe "when `indent` is triggered", ->
        it "auto-indents the line", ->
          editor.setCursorBufferPosition([1, 30])
          editor.insertText("\n ")
          expect(editor.lineTextForBufferRow(2)).toBe " "

          atom.config.set("editor.autoIndent", true)
          editor.indent()
          expect(editor.lineTextForBufferRow(2)).toBe "    "

      describe "when a newline is added", ->
        describe "when the line preceding the newline adds a new level of indentation", ->
          it "indents the newline to one additional level of indentation beyond the preceding line", ->
            editor.setCursorBufferPosition([1, Infinity])
            editor.insertText('\n')
            expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1) + 1

        describe "when the line preceding the newline does't add a level of indentation", ->
          it "indents the new line to the same level a as the preceding line", ->
            editor.setCursorBufferPosition([5, 14])
            editor.insertText('\n')
            expect(editor.indentationForBufferRow(6)).toBe editor.indentationForBufferRow(5)

        describe "when the line preceding the newline is a comment", ->
          it "maintains the indent of the commented line", ->
            editor.setCursorBufferPosition([0, 0])
            editor.insertText('    //')
            editor.setCursorBufferPosition([0, Infinity])
            editor.insertText('\n')
            expect(editor.indentationForBufferRow(1)).toBe 2

        describe "when the line preceding the newline contains only whitespace", ->
          it "bases the new line's indentation on only the preceding line", ->
            editor.setCursorBufferPosition([6, Infinity])
            editor.insertText("\n  ")
            expect(editor.getCursorBufferPosition()).toEqual([7, 2])

            editor.insertNewline()
            expect(editor.lineTextForBufferRow(8)).toBe("  ")

        it "does not indent the line preceding the newline", ->
          editor.setCursorBufferPosition([2, 0])
          editor.insertText('  var this-line-should-be-indented-more\n')
          expect(editor.indentationForBufferRow(1)).toBe 1

          atom.config.set("editor.autoIndent", true)
          editor.setCursorBufferPosition([2, Infinity])
          editor.insertText('\n')
          expect(editor.indentationForBufferRow(1)).toBe 1
          expect(editor.indentationForBufferRow(2)).toBe 1

        describe "when the cursor is before whitespace", ->
          it "retains the whitespace following the cursor on the new line", ->
            editor.setText("  var sort = function() {}")
            editor.setCursorScreenPosition([0, 12])
            editor.insertNewline()

            expect(buffer.lineForRow(0)).toBe '  var sort ='
            expect(buffer.lineForRow(1)).toBe '   function() {}'
            expect(editor.getCursorScreenPosition()).toEqual [1, 2]

      describe "when inserted text matches a decrease indent pattern", ->
        describe "when the preceding line matches an increase indent pattern", ->
          it "decreases the indentation to match that of the preceding line", ->
            editor.setCursorBufferPosition([1, Infinity])
            editor.insertText('\n')
            expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1) + 1
            editor.insertText('}')
            expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1)

        describe "when the preceding line doesn't match an increase indent pattern", ->
          it "decreases the indentation to be one level below that of the preceding line", ->
            editor.setCursorBufferPosition([3, Infinity])
            editor.insertText('\n    ')
            expect(editor.indentationForBufferRow(4)).toBe editor.indentationForBufferRow(3)
            editor.insertText('}')
            expect(editor.indentationForBufferRow(4)).toBe editor.indentationForBufferRow(3) - 1

          it "doesn't break when decreasing the indentation on a row that has no indentation", ->
            editor.setCursorBufferPosition([12, Infinity])
            editor.insertText("\n}; # too many closing brackets!")
            expect(editor.lineTextForBufferRow(13)).toBe "}; # too many closing brackets!"

      describe "when inserted text does not match a decrease indent pattern", ->
        it "does not decrease the indentation", ->
          editor.setCursorBufferPosition([12, 0])
          editor.insertText('  ')
          expect(editor.lineTextForBufferRow(12)).toBe '  };'
          editor.insertText('\t\t')
          expect(editor.lineTextForBufferRow(12)).toBe '  \t\t};'

      describe "when the current line does not match a decrease indent pattern", ->
        it "leaves the line unchanged", ->
          editor.setCursorBufferPosition([2, 4])
          expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1) + 1
          editor.insertText('foo')
          expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1) + 1

    describe 'when scoped settings are used', ->
      coffeeEditor = null
      beforeEach ->
        waitsForPromise ->
          atom.packages.activatePackage('language-coffee-script')
        waitsForPromise ->
          atom.project.open('coffee.coffee', autoIndent: false).then (o) -> coffeeEditor = o

        runs ->
          atom.config.set('editor.autoIndent', true, scopeSelector: '.source.js')
          atom.config.set('editor.autoIndent', false, scopeSelector: '.source.coffee')

      afterEach: ->
        atom.packages.deactivatePackages()
        atom.packages.unloadPackages()

      it "does not auto-indent the line for javascript files", ->
        editor.setCursorBufferPosition([1, 30])
        editor.insertText("\n")
        expect(editor.lineTextForBufferRow(2)).toBe "    "

        coffeeEditor.setCursorBufferPosition([1, 18])
        coffeeEditor.insertText("\n")
        expect(coffeeEditor.lineTextForBufferRow(2)).toBe ""

  describe "soft and hard tabs", ->
    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    it "resets the tab style when tokenization is complete", ->
      editor.destroy()

      waitsForPromise ->
        atom.project.open('sample-with-tabs-and-leading-comment.coffee').then (o) -> editor = o

      runs ->
        expect(editor.softTabs).toBe true

      waitsForPromise ->
        atom.packages.activatePackage('language-coffee-script')

      runs ->
        expect(editor.softTabs).toBe false

    it "uses hard tabs in Makefile files", ->
      # FIXME remove once this is handled by a scoped setting in the
      # language-make package

      waitsForPromise ->
        atom.packages.activatePackage('language-make')

      waitsForPromise ->
        atom.project.open('Makefile').then (o) -> editor = o

      runs ->
        expect(editor.softTabs).toBe false

  describe ".destroy()", ->
    it "destroys all markers associated with the edit session", ->
      expect(buffer.getMarkerCount()).toBeGreaterThan 0
      editor.destroy()
      expect(buffer.getMarkerCount()).toBe 0

    it "notifies ::onDidDestroy observers when the editor is destroyed", ->
      destroyObserverCalled = false
      editor.onDidDestroy -> destroyObserverCalled = true

      editor.destroy()
      expect(destroyObserverCalled).toBe true

  describe ".joinLines()", ->
    describe "when no text is selected", ->
      describe "when the line below isn't empty", ->
        it "joins the line below with the current line separated by a space and moves the cursor to the start of line that was moved up", ->
          editor.setCursorBufferPosition([0, Infinity])
          editor.insertText('  ')
          editor.setCursorBufferPosition([0])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(0)).toBe 'var quicksort = function () { var sort = function(items) {'
          expect(editor.getCursorBufferPosition()).toEqual [0, 29]

      describe "when the line below is empty", ->
        it "deletes the line below and moves the cursor to the end of the line", ->
          editor.setCursorBufferPosition([9])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(9)).toBe '  };'
          expect(editor.lineTextForBufferRow(10)).toBe '  return sort(Array.apply(this, arguments));'
          expect(editor.getCursorBufferPosition()).toEqual [9, 4]

      describe "when the cursor is on the last row", ->
        it "does nothing", ->
          editor.setCursorBufferPosition([Infinity, Infinity])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(12)).toBe '};'

      describe "when the line is empty", ->
        it "joins the line below with the current line with no added space", ->
          editor.setCursorBufferPosition([10])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(10)).toBe 'return sort(Array.apply(this, arguments));'
          expect(editor.getCursorBufferPosition()).toEqual [10, 0]

    describe "when text is selected", ->
      describe "when the selection does not span multiple lines", ->
        it "joins the line below with the current line separated by a space and retains the selected text", ->
          editor.setSelectedBufferRange([[0, 1], [0, 3]])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(0)).toBe 'var quicksort = function () { var sort = function(items) {'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 3]]

      describe "when the selection spans multiple lines", ->
        it "joins all selected lines separated by a space and retains the selected text", ->
          editor.setSelectedBufferRange([[9, 3], [12, 1]])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(9)).toBe '  }; return sort(Array.apply(this, arguments)); };'
          expect(editor.getSelectedBufferRange()).toEqual [[9, 3], [9, 49]]

  describe ".duplicateLines()", ->
    it "for each selection, duplicates all buffer lines intersected by the selection", ->
      editor.foldBufferRow(4)
      editor.setCursorBufferPosition([2, 5])
      editor.addSelectionForBufferRange([[3, 0], [8, 0]], preserveFolds: true)

      editor.duplicateLines()

      expect(editor.getTextInBufferRange([[2, 0], [13, 5]])).toBe  """
        \    if (items.length <= 1) return items;
            if (items.length <= 1) return items;
            var pivot = items.shift(), current, left = [], right = [];
            while(items.length > 0) {
              current = items.shift();
              current < pivot ? left.push(current) : right.push(current);
            }
            var pivot = items.shift(), current, left = [], right = [];
            while(items.length > 0) {
              current = items.shift();
              current < pivot ? left.push(current) : right.push(current);
            }
      """
      expect(editor.getSelectedBufferRanges()).toEqual [[[3, 5], [3, 5]], [[9, 0], [14, 0]]]

      # folds are also duplicated
      expect(editor.tokenizedLineForScreenRow(5).fold).toBeDefined()
      expect(editor.tokenizedLineForScreenRow(7).fold).toBeDefined()
      expect(editor.tokenizedLineForScreenRow(7).text).toBe "    while(items.length > 0) {"
      expect(editor.tokenizedLineForScreenRow(8).text).toBe "    return sort(left).concat(pivot).concat(sort(right));"

    it "duplicates all folded lines for empty selections on folded lines", ->
      editor.foldBufferRow(4)
      editor.setCursorBufferPosition([4, 0])

      editor.duplicateLines()

      expect(editor.getTextInBufferRange([[2, 0], [11, 5]])).toBe  """
        \    if (items.length <= 1) return items;
            var pivot = items.shift(), current, left = [], right = [];
            while(items.length > 0) {
              current = items.shift();
              current < pivot ? left.push(current) : right.push(current);
            }
            while(items.length > 0) {
              current = items.shift();
              current < pivot ? left.push(current) : right.push(current);
            }
      """
      expect(editor.getSelectedBufferRange()).toEqual [[8, 0], [8, 0]]

    it "can duplicate the last line of the buffer", ->
      editor.setSelectedBufferRange([[11, 0], [12, 2]])
      editor.duplicateLines()
      expect(editor.getTextInBufferRange([[11, 0], [14, 2]])).toBe """
        \  return sort(Array.apply(this, arguments));
        };
          return sort(Array.apply(this, arguments));
        };
      """
      expect(editor.getSelectedBufferRange()).toEqual [[13, 0], [14, 2]]

  describe ".shouldPromptToSave()", ->
    it "returns false when an edit session's buffer is in use by more than one session", ->
      jasmine.unspy(editor, 'shouldPromptToSave')
      expect(editor.shouldPromptToSave()).toBeFalsy()
      buffer.setText('changed')
      expect(editor.shouldPromptToSave()).toBeTruthy()

      editor2 = null
      waitsForPromise ->
        atom.project.open('sample.js', autoIndent: false).then (o) -> editor2 = o

      runs ->
        expect(editor.shouldPromptToSave()).toBeFalsy()
        editor2.destroy()
        expect(editor.shouldPromptToSave()).toBeTruthy()

  describe "when the editor contains surrogate pair characters", ->
    it "correctly backspaces over them", ->
      editor.setText('\uD835\uDF97\uD835\uDF97\uD835\uDF97')
      editor.moveToBottom()
      editor.backspace()
      expect(editor.getText()).toBe '\uD835\uDF97\uD835\uDF97'
      editor.backspace()
      expect(editor.getText()).toBe '\uD835\uDF97'
      editor.backspace()
      expect(editor.getText()).toBe ''

    it "correctly deletes over them", ->
      editor.setText('\uD835\uDF97\uD835\uDF97\uD835\uDF97')
      editor.moveToTop()
      editor.delete()
      expect(editor.getText()).toBe '\uD835\uDF97\uD835\uDF97'
      editor.delete()
      expect(editor.getText()).toBe '\uD835\uDF97'
      editor.delete()
      expect(editor.getText()).toBe ''

    it "correctly moves over them", ->
      editor.setText('\uD835\uDF97\uD835\uDF97\uD835\uDF97\n')
      editor.moveToTop()
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 2]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 4]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 6]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [1, 0]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 6]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 4]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 2]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

  describe "when the editor contains variation sequence character pairs", ->
    it "correctly backspaces over them", ->
      editor.setText('\u2714\uFE0E\u2714\uFE0E\u2714\uFE0E')
      editor.moveToBottom()
      editor.backspace()
      expect(editor.getText()).toBe '\u2714\uFE0E\u2714\uFE0E'
      editor.backspace()
      expect(editor.getText()).toBe '\u2714\uFE0E'
      editor.backspace()
      expect(editor.getText()).toBe ''

    it "correctly deletes over them", ->
      editor.setText('\u2714\uFE0E\u2714\uFE0E\u2714\uFE0E')
      editor.moveToTop()
      editor.delete()
      expect(editor.getText()).toBe '\u2714\uFE0E\u2714\uFE0E'
      editor.delete()
      expect(editor.getText()).toBe '\u2714\uFE0E'
      editor.delete()
      expect(editor.getText()).toBe ''

    it "correctly moves over them", ->
      editor.setText('\u2714\uFE0E\u2714\uFE0E\u2714\uFE0E\n')
      editor.moveToTop()
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 2]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 4]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 6]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [1, 0]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 6]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 4]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 2]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

  describe ".setIndentationForBufferRow", ->
    describe "when the editor uses soft tabs but the row has hard tabs", ->
      it "only replaces whitespace characters", ->
        editor.setSoftWrapped(true)
        editor.setText("\t1\n\t2")
        editor.setCursorBufferPosition([0, 0])
        editor.setIndentationForBufferRow(0, 2)
        expect(editor.getText()).toBe("    1\n\t2")

    describe "when the indentation level is a non-integer", ->
      it "does not throw an exception", ->
        editor.setSoftWrapped(true)
        editor.setText("\t1\n\t2")
        editor.setCursorBufferPosition([0, 0])
        editor.setIndentationForBufferRow(0, 2.1)
        expect(editor.getText()).toBe("    1\n\t2")

  describe ".reloadGrammar()", ->
    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage('language-coffee-script')

    it "updates the grammar based on grammar overrides", ->
      expect(editor.getGrammar().name).toBe 'JavaScript'
      atom.grammars.setGrammarOverrideForPath(editor.getPath(), 'source.coffee')
      callback = jasmine.createSpy('callback')
      editor.onDidChangeGrammar(callback)
      editor.reloadGrammar()
      expect(editor.getGrammar().name).toBe 'CoffeeScript'
      expect(callback.callCount).toBe 1
      expect(callback.argsForCall[0][0]).toBe atom.grammars.grammarForScopeName('source.coffee')

  describe "when the editor's grammar has an injection selector", ->
    beforeEach ->

      waitsForPromise ->
        atom.packages.activatePackage('language-text')

      waitsForPromise ->
        atom.packages.activatePackage('language-javascript')

    it "includes the grammar's patterns when the selector matches the current scope in other grammars", ->
      waitsForPromise ->
        atom.packages.activatePackage('language-hyperlink')

      runs ->
        grammar = atom.grammars.selectGrammar("text.js")
        {tokens} = grammar.tokenizeLine("var i; // http://github.com")

        expect(tokens[0].value).toBe "var"
        expect(tokens[0].scopes).toEqual ["source.js", "storage.modifier.js"]

        expect(tokens[6].value).toBe "http://github.com"
        expect(tokens[6].scopes).toEqual ["source.js", "comment.line.double-slash.js", "markup.underline.link.http.hyperlink"]

    describe "when the grammar is added", ->
      it "retokenizes existing buffers that contain tokens that match the injection selector", ->
        waitsForPromise ->
          atom.workspace.open('sample.js').then (o) -> editor = o

        runs ->
          editor.setText("// http://github.com")

          {tokens} = editor.tokenizedLineForScreenRow(0)
          expect(tokens[1].value).toBe " http://github.com"
          expect(tokens[1].scopes).toEqual ["source.js", "comment.line.double-slash.js"]

        waitsForPromise ->
          atom.packages.activatePackage('language-hyperlink')

        runs ->
          {tokens} = editor.tokenizedLineForScreenRow(0)
          expect(tokens[2].value).toBe "http://github.com"
          expect(tokens[2].scopes).toEqual ["source.js", "comment.line.double-slash.js", "markup.underline.link.http.hyperlink"]

      describe "when the grammar is updated", ->
        it "retokenizes existing buffers that contain tokens that match the injection selector", ->
          waitsForPromise ->
            atom.workspace.open('sample.js').then (o) -> editor = o

          runs ->
            editor.setText("// SELECT * FROM OCTOCATS")

            {tokens} = editor.tokenizedLineForScreenRow(0)
            expect(tokens[1].value).toBe " SELECT * FROM OCTOCATS"
            expect(tokens[1].scopes).toEqual ["source.js", "comment.line.double-slash.js"]

          waitsForPromise ->
            atom.packages.activatePackage('package-with-injection-selector')

          runs ->
            {tokens} = editor.tokenizedLineForScreenRow(0)
            expect(tokens[1].value).toBe " SELECT * FROM OCTOCATS"
            expect(tokens[1].scopes).toEqual ["source.js", "comment.line.double-slash.js"]

          waitsForPromise ->
            atom.packages.activatePackage('language-sql')

          runs ->
            {tokens} = editor.tokenizedLineForScreenRow(0)
            expect(tokens[2].value).toBe "SELECT"
            expect(tokens[2].scopes).toEqual ["source.js", "comment.line.double-slash.js", "keyword.other.DML.sql"]

  describe ".normalizeTabsInBufferRange()", ->
    it "normalizes tabs depending on the editor's soft tab/tab length settings", ->
      editor.setTabLength(1)
      editor.setSoftTabs(true)
      editor.setText('\t\t\t')
      editor.normalizeTabsInBufferRange([[0, 0], [0, 1]])
      expect(editor.getText()).toBe ' \t\t'

      editor.setTabLength(2)
      editor.normalizeTabsInBufferRange([[0, 0], [Infinity, Infinity]])
      expect(editor.getText()).toBe '     '

      editor.setSoftTabs(false)
      editor.normalizeTabsInBufferRange([[0, 0], [Infinity, Infinity]])
      expect(editor.getText()).toBe '     '

  describe ".scrollToCursorPosition()", ->
    it "scrolls the last cursor into view, centering around the cursor if possible and the 'center' option isn't false", ->
      editor.setCursorScreenPosition([8, 8])
      editor.setLineHeightInPixels(10)
      editor.setDefaultCharWidth(10)
      editor.setHeight(60)
      editor.setWidth(130)
      editor.setHorizontalScrollbarHeight(0)
      expect(editor.getScrollTop()).toBe 0
      expect(editor.getScrollLeft()).toBe 0

      editor.scrollToCursorPosition()
      expect(editor.getScrollTop()).toBe (8.5 * 10) - 30
      expect(editor.getScrollBottom()).toBe (8.5 * 10) + 30
      expect(editor.getScrollRight()).toBe (9 + editor.getHorizontalScrollMargin()) * 10

      editor.setScrollTop(0)
      editor.scrollToCursorPosition(center: false)
      expect(editor.getScrollBottom()).toBe (9 + editor.getVerticalScrollMargin()) * 10

  describe ".pageUp/Down()", ->
    it "scrolls one screen height up or down and moves the cursor one page length", ->
      editor.setLineHeightInPixels(10)
      editor.setHeight(50)
      expect(editor.getScrollHeight()).toBe 130
      expect(editor.getCursorBufferPosition().row).toBe 0

      editor.pageDown()
      expect(editor.getScrollTop()).toBe 50
      expect(editor.getCursorBufferPosition().row).toBe 5

      editor.pageDown()
      expect(editor.getScrollTop()).toBe 80
      expect(editor.getCursorBufferPosition().row).toBe 10

      editor.pageUp()
      expect(editor.getScrollTop()).toBe 30
      expect(editor.getCursorBufferPosition().row).toBe 5

      editor.pageUp()
      expect(editor.getScrollTop()).toBe 0
      expect(editor.getCursorBufferPosition().row).toBe 0

  describe ".selectPageUp/Down()", ->
    it "selects one screen height of text up or down", ->
      editor.setLineHeightInPixels(10)
      editor.setHeight(50)
      expect(editor.getScrollHeight()).toBe 130
      expect(editor.getCursorBufferPosition().row).toBe 0

      editor.selectPageDown()
      expect(editor.getScrollTop()).toBe 30
      expect(editor.getSelectedBufferRanges()).toEqual [[[0,0], [5,0]]]

      editor.selectPageDown()
      expect(editor.getScrollTop()).toBe 80
      expect(editor.getSelectedBufferRanges()).toEqual [[[0,0], [10,0]]]

      editor.selectPageDown()
      expect(editor.getScrollTop()).toBe 80
      expect(editor.getSelectedBufferRanges()).toEqual [[[0,0], [12,2]]]

      editor.moveToBottom()
      editor.selectPageUp()
      expect(editor.getScrollTop()).toBe 50
      expect(editor.getSelectedBufferRanges()).toEqual [[[7,0], [12,2]]]

      editor.selectPageUp()
      expect(editor.getScrollTop()).toBe 0
      expect(editor.getSelectedBufferRanges()).toEqual [[[2,0], [12,2]]]

      editor.selectPageUp()
      expect(editor.getScrollTop()).toBe 0
      expect(editor.getSelectedBufferRanges()).toEqual [[[0,0], [12,2]]]

  describe '.get/setPlaceholderText()', ->
    it 'can be created with placeholderText', ->
      TextBuffer = require 'text-buffer'
      newEditor = new TextEditor
        buffer: new TextBuffer
        mini: true
        placeholderText: 'yep'
      expect(newEditor.getPlaceholderText()).toBe 'yep'

    it 'models placeholderText and emits an event when changed', ->
      editor.onDidChangePlaceholderText handler = jasmine.createSpy()

      expect(editor.getPlaceholderText()).toBeUndefined()

      editor.setPlaceholderText('OK')
      expect(handler).toHaveBeenCalledWith 'OK'
      expect(editor.getPlaceholderText()).toBe 'OK'

  describe ".checkoutHeadRevision()", ->
    it "reverts to the version of its file checked into the project repository", ->
      atom.config.set("editor.confirmCheckoutHeadRevision", false)

      editor.setCursorBufferPosition([0, 0])
      editor.insertText("---\n")
      expect(editor.lineTextForBufferRow(0)).toBe "---"

      waitsForPromise ->
        editor.checkoutHeadRevision()

      runs ->
        expect(editor.lineTextForBufferRow(0)).toBe "var quicksort = function () {"

    describe "when there's no repository for the editor's file", ->
      it "doesn't do anything", ->
        editor = new TextEditor({})
        editor.setText("stuff")
        editor.checkoutHeadRevision()

        waitsForPromise -> editor.checkoutHeadRevision()
