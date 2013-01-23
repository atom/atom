Project = require 'project'
Buffer = require 'buffer'
EditSession = require 'edit-session'

describe "LanguageMode", ->
  [editSession, buffer, languageMode] = []

  afterEach ->
    editSession.destroy()

  describe "common behavior", ->
    beforeEach ->
      editSession = fixturesProject.buildEditSessionForPath('sample.js', autoIndent: false)
      { buffer, languageMode } = editSession

    describe "language detection", ->
      it "uses the file name as the file type if it has no extension", ->
        jsEditSession = fixturesProject.buildEditSessionForPath('js', autoIndent: false)
        expect(jsEditSession.languageMode.grammar.name).toBe "JavaScript"
        jsEditSession.destroy()

    describe "bracket insertion", ->
      beforeEach ->
        editSession.buffer.setText("")

      describe "when more than one character is inserted", ->
        it "does not insert a matching bracket", ->
          editSession.insertText("woah(")
          expect(editSession.buffer.getText()).toBe "woah("

      describe "when there is a word character after the cursor", ->
        it "does not insert a matching bracket", ->
          editSession.buffer.setText("ab")
          editSession.setCursorBufferPosition([0, 1])
          editSession.insertText("(")

          expect(editSession.buffer.getText()).toBe "a(b"

      describe "when there are multiple cursors", ->
        it "inserts ) at each cursor", ->
          editSession.buffer.setText("()\nab\n[]\n12")
          editSession.setCursorBufferPosition([3, 1])
          editSession.addCursorAtBufferPosition([2, 1])
          editSession.addCursorAtBufferPosition([1, 1])
          editSession.addCursorAtBufferPosition([0, 1])
          editSession.insertText ')'

          expect(editSession.buffer.getText()).toBe "())\na)b\n[)]\n1)2"

      describe "when there is a non-word character after the cursor", ->
        it "inserts a closing bracket after an opening bracket is inserted", ->
          editSession.buffer.setText("}")
          editSession.setCursorBufferPosition([0, 0])
          editSession.insertText '{'
          expect(buffer.lineForRow(0)).toBe "{}}"
          expect(editSession.getCursorBufferPosition()).toEqual([0,1])

      describe "when the cursor is at the end of the line", ->
        it "inserts a closing bracket after an opening bracket is inserted", ->
          editSession.buffer.setText("")
          editSession.insertText '{'
          expect(buffer.lineForRow(0)).toBe "{}"
          expect(editSession.getCursorBufferPosition()).toEqual([0,1])

          editSession.buffer.setText("")
          editSession.insertText '('
          expect(buffer.lineForRow(0)).toBe "()"
          expect(editSession.getCursorBufferPosition()).toEqual([0,1])

          editSession.buffer.setText("")
          editSession.insertText '['
          expect(buffer.lineForRow(0)).toBe "[]"
          expect(editSession.getCursorBufferPosition()).toEqual([0,1])

          editSession.buffer.setText("")
          editSession.insertText '"'
          expect(buffer.lineForRow(0)).toBe '""'
          expect(editSession.getCursorBufferPosition()).toEqual([0,1])

          editSession.buffer.setText("")
          editSession.insertText "'"
          expect(buffer.lineForRow(0)).toBe "''"
          expect(editSession.getCursorBufferPosition()).toEqual([0,1])

      describe "when the cursor is on a closing bracket and a closing bracket is inserted", ->
        describe "when the closing bracket was there previously", ->
          it "inserts a closing bracket", ->
            editSession.insertText '()x'
            editSession.setCursorBufferPosition([0, 1])
            editSession.insertText ')'
            expect(buffer.lineForRow(0)).toBe "())x"
            expect(editSession.getCursorBufferPosition().column).toBe 2

        describe "when the closing bracket was automatically inserted from inserting an opening bracket", ->
          it "only moves cursor over the closing bracket one time", ->
            editSession.insertText '('
            expect(buffer.lineForRow(0)).toBe "()"
            editSession.setCursorBufferPosition([0, 1])
            editSession.insertText ')'
            expect(buffer.lineForRow(0)).toBe "()"
            expect(editSession.getCursorBufferPosition()).toEqual [0, 2]

            editSession.setCursorBufferPosition([0, 1])
            editSession.insertText ')'
            expect(buffer.lineForRow(0)).toBe "())"
            expect(editSession.getCursorBufferPosition()).toEqual [0, 2]

          it "moves cursor over the closing bracket after other text is inserted", ->
            editSession.insertText '('
            editSession.insertText 'ok cool'
            expect(buffer.lineForRow(0)).toBe "(ok cool)"
            editSession.setCursorBufferPosition([0, 8])
            editSession.insertText ')'
            expect(buffer.lineForRow(0)).toBe "(ok cool)"
            expect(editSession.getCursorBufferPosition()).toEqual [0, 9]

          it "works with nested brackets", ->
            editSession.insertText '('
            editSession.insertText '1'
            editSession.insertText '('
            editSession.insertText '2'
            expect(buffer.lineForRow(0)).toBe "(1(2))"
            editSession.setCursorBufferPosition([0, 4])
            editSession.insertText ')'
            expect(buffer.lineForRow(0)).toBe "(1(2))"
            expect(editSession.getCursorBufferPosition()).toEqual [0, 5]
            editSession.insertText ')'
            expect(buffer.lineForRow(0)).toBe "(1(2))"
            expect(editSession.getCursorBufferPosition()).toEqual [0, 6]

          it "works with mixed brackets", ->
            editSession.insertText '('
            editSession.insertText '}'
            expect(buffer.lineForRow(0)).toBe "(})"
            editSession.insertText ')'
            expect(buffer.lineForRow(0)).toBe "(})"
            expect(editSession.getCursorBufferPosition()).toEqual [0, 3]

          it "closes brackets with the same begin/end character correctly", ->
            editSession.insertText '"'
            editSession.insertText 'ok'
            expect(buffer.lineForRow(0)).toBe '"ok"'
            expect(editSession.getCursorBufferPosition()).toEqual [0, 3]
            editSession.insertText '"'
            expect(buffer.lineForRow(0)).toBe '"ok"'
            expect(editSession.getCursorBufferPosition()).toEqual [0, 4]

      describe "when inserting a quote", ->
        describe "when a word character is before the cursor", ->
          it "does not automatically insert closing quote", ->
            editSession.buffer.setText("abc")
            editSession.setCursorBufferPosition([0, 3])
            editSession.insertText '"'
            expect(buffer.lineForRow(0)).toBe "abc\""

            editSession.buffer.setText("abc")
            editSession.setCursorBufferPosition([0, 3])
            editSession.insertText '\''
            expect(buffer.lineForRow(0)).toBe "abc\'"

        describe "when a non word character is before the cursor", ->
          it "automatically insert closing quote", ->
            editSession.buffer.setText("ab@")
            editSession.setCursorBufferPosition([0, 3])
            editSession.insertText '"'
            expect(buffer.lineForRow(0)).toBe "ab@\"\""
            expect(editSession.getCursorBufferPosition()).toEqual [0, 4]

        describe "when the cursor is on an empty line", ->
          it "automatically insert closing quote", ->
            editSession.buffer.setText("")
            editSession.setCursorBufferPosition([0, 0])
            editSession.insertText '"'
            expect(buffer.lineForRow(0)).toBe "\"\""
            expect(editSession.getCursorBufferPosition()).toEqual [0, 1]

    describe "bracket deletion", ->
      it "deletes the end bracket when it directly proceeds a begin bracket that is being backspaced", ->
        buffer.setText("")
        editSession.setCursorBufferPosition([0, 0])
        editSession.insertText '{'
        expect(buffer.lineForRow(0)).toBe "{}"
        editSession.backspace()
        expect(buffer.lineForRow(0)).toBe ""

  describe "javascript", ->
    beforeEach ->
      editSession = fixturesProject.buildEditSessionForPath('sample.js', autoIndent: false)
      { buffer, languageMode } = editSession

    describe ".toggleLineCommentsForBufferRows(start, end)", ->
      it "comments/uncomments lines in the given range", ->
        languageMode.toggleLineCommentsForBufferRows(4, 7)
        expect(buffer.lineForRow(4)).toBe "//     while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "//       current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "//       current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "//     }"

        languageMode.toggleLineCommentsForBufferRows(4, 5)
        expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "//       current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "//     }"

    describe "fold suggestion", ->
      describe ".doesBufferRowStartFold(bufferRow)", ->
        it "returns true only when the buffer row starts a foldable region", ->
          expect(languageMode.doesBufferRowStartFold(0)).toBeTruthy()
          expect(languageMode.doesBufferRowStartFold(1)).toBeTruthy()
          expect(languageMode.doesBufferRowStartFold(2)).toBeFalsy()
          expect(languageMode.doesBufferRowStartFold(3)).toBeFalsy()

      describe ".rowRangeForFoldAtBufferRow(bufferRow)", ->
        it "returns the start/end rows of the foldable region starting at the given row", ->
          expect(languageMode.rowRangeForFoldAtBufferRow(0)).toEqual [0, 12]
          expect(languageMode.rowRangeForFoldAtBufferRow(1)).toEqual [1, 9]
          expect(languageMode.rowRangeForFoldAtBufferRow(2)).toBeNull()
          expect(languageMode.rowRangeForFoldAtBufferRow(4)).toEqual [4, 7]

    describe "suggestedIndentForBufferRow", ->
      it "returns the suggested indentation based on auto-indent/outdent rules", ->
        expect(languageMode.suggestedIndentForBufferRow(0)).toBe 0
        expect(languageMode.suggestedIndentForBufferRow(1)).toBe 1
        expect(languageMode.suggestedIndentForBufferRow(2)).toBe 2
        expect(languageMode.suggestedIndentForBufferRow(9)).toBe 1


  describe "coffeescript", ->
    beforeEach ->
      editSession = fixturesProject.buildEditSessionForPath('coffee.coffee', autoIndent: false)
      { buffer, languageMode } = editSession

    describe ".toggleLineCommentsForBufferRows(start, end)", ->
      it "comments/uncomments lines in the given range", ->
        languageMode.toggleLineCommentsForBufferRows(4, 7)
        expect(buffer.lineForRow(4)).toBe "#     pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "#     left = []"
        expect(buffer.lineForRow(6)).toBe "#     right = []"
        expect(buffer.lineForRow(7)).toBe "# "

        languageMode.toggleLineCommentsForBufferRows(4, 5)
        expect(buffer.lineForRow(4)).toBe "    pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "    left = []"
        expect(buffer.lineForRow(6)).toBe "#     right = []"
        expect(buffer.lineForRow(7)).toBe "# "

    describe "fold suggestion", ->
      describe ".doesBufferRowStartFold(bufferRow)", ->
        it "returns true only when the buffer row starts a foldable region", ->
          expect(languageMode.doesBufferRowStartFold(0)).toBeTruthy()
          expect(languageMode.doesBufferRowStartFold(1)).toBeTruthy()
          expect(languageMode.doesBufferRowStartFold(2)).toBeFalsy()
          expect(languageMode.doesBufferRowStartFold(3)).toBeFalsy()
          expect(languageMode.doesBufferRowStartFold(19)).toBeTruthy()

      describe ".rowRangeForFoldAtBufferRow(bufferRow)", ->
        it "returns the start/end rows of the foldable region starting at the given row", ->
          expect(languageMode.rowRangeForFoldAtBufferRow(0)).toEqual [0, 20]
          expect(languageMode.rowRangeForFoldAtBufferRow(1)).toEqual [1, 17]
          expect(languageMode.rowRangeForFoldAtBufferRow(2)).toBeNull()
          expect(languageMode.rowRangeForFoldAtBufferRow(19)).toEqual [19, 20]

  describe "css", ->
    beforeEach ->
      editSession = fixturesProject.buildEditSessionForPath('css.css', autoIndent: false)
      { buffer, languageMode } = editSession

    describe ".toggleLineCommentsForBufferRows(start, end)", ->
      it "comments/uncomments lines in the given range", ->
        languageMode.toggleLineCommentsForBufferRows(0, 1)
        expect(buffer.lineForRow(0)).toBe "/*body {"
        expect(buffer.lineForRow(1)).toBe "  font-size: 1234px;*/"
        expect(buffer.lineForRow(2)).toBe "  width: 110%;"
        expect(buffer.lineForRow(3)).toBe "  font-weight: bold !important;"

        languageMode.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(0)).toBe "/*body {"
        expect(buffer.lineForRow(1)).toBe "  font-size: 1234px;*/"
        expect(buffer.lineForRow(2)).toBe "/*  width: 110%;*/"
        expect(buffer.lineForRow(3)).toBe "  font-weight: bold !important;"

        languageMode.toggleLineCommentsForBufferRows(0, 1)
        expect(buffer.lineForRow(0)).toBe "body {"
        expect(buffer.lineForRow(1)).toBe "  font-size: 1234px;"
        expect(buffer.lineForRow(2)).toBe "/*  width: 110%;*/"
        expect(buffer.lineForRow(3)).toBe "  font-weight: bold !important;"

      it "uncomments lines with leading whitespace", ->
        buffer.replaceLines(2, 2, "  /*width: 110%;*/")
        languageMode.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(2)).toBe "  width: 110%;"

      it "uncomments lines with trailing whitespace", ->
        buffer.replaceLines(2, 2, "/*width: 110%;*/  ")
        languageMode.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(2)).toBe "width: 110%;  "

      it "uncomments lines with leading and trailing whitespace", ->
        buffer.replaceLines(2, 2, "   /*width: 110%;*/ ")
        languageMode.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(2)).toBe "   width: 110%; "
