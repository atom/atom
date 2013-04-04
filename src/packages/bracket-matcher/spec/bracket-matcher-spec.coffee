RootView = require 'root-view'

describe "bracket matching", ->
  [editor, editSession, buffer] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    atom.activatePackage('bracket-matcher')
    rootView.attachToDom()
    editor = rootView.getActiveView()
    editSession = editor.activeEditSession
    buffer = editSession.buffer

  describe "matching bracket highlighting", ->
    describe "when the cursor is before a starting pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveCursorToEndOfLine()
        editor.moveCursorLeft()
        expect(editor.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([0,28])
        expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([12,0])

    describe "when the cursor is after a starting pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveCursorToEndOfLine()
        expect(editor.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([0,28])
        expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([12,0])

    describe "when the cursor is before an ending pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveCursorToBottom()
        editor.moveCursorLeft()
        editor.moveCursorLeft()
        expect(editor.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([12,0])
        expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([0,28])

    describe "when the cursor is after an ending pair", ->
      it "highlights the starting pair and ending pair", ->
        editor.moveCursorToBottom()
        editor.moveCursorLeft()
        expect(editor.underlayer.find('.bracket-matcher:visible').length).toBe 2
        expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([12,0])
        expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([0,28])

    describe "when the cursor is moved off a pair", ->
      it "removes the starting pair and ending pair highlights", ->
        editor.moveCursorToEndOfLine()
        expect(editor.underlayer.find('.bracket-matcher:visible').length).toBe 2
        editor.moveCursorToBeginningOfLine()
        expect(editor.underlayer.find('.bracket-matcher:visible').length).toBe 0

    describe "pair balancing", ->
      describe "when a second starting pair preceeds the first ending pair", ->
        it "advances to the second ending pair", ->
          editor.setCursorBufferPosition([8,42])
          expect(editor.underlayer.find('.bracket-matcher:visible').length).toBe 2
          expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([8,42])
          expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([8,54])

  describe "when editor:go-to-matching-bracket is triggered", ->
    describe "when the cursor is before the starting pair", ->
      it "moves the cursor to after the ending pair", ->
        editor.moveCursorToEndOfLine()
        editor.moveCursorLeft()
        editor.trigger "editor:go-to-matching-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [12, 1]

    describe "when the cursor is after the starting pair", ->
      it "moves the cursor to before the ending pair", ->
        editor.moveCursorToEndOfLine()
        editor.trigger "editor:go-to-matching-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [12, 0]

    describe "when the cursor is before the ending pair", ->
      it "moves the cursor to after the starting pair", ->
        editor.setCursorBufferPosition([12, 0])
        editor.trigger "editor:go-to-matching-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [0, 29]

    describe "when the cursor is after the ending pair", ->
      it "moves the cursor to before the starting pair", ->
        editor.setCursorBufferPosition([12, 1])
        editor.trigger "editor:go-to-matching-bracket"
        expect(editor.getCursorBufferPosition()).toEqual [0, 28]

  describe "matching bracket insertion", ->
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

    describe "when there is text selected on a single line", ->
      it "wraps the selection with brackets", ->
        editSession.insertText 'text'
        editSession.moveCursorToBottom()
        editSession.selectToTop()
        editSession.selectAll()
        editSession.insertText '('
        expect('(text)').toBe buffer.getText()
        expect(editSession.getSelectedBufferRange()).toEqual [[0, 1], [0, 5]]
        expect(editSession.getSelection().isReversed()).toBeTruthy()

    describe "when there is text selected on multiple lines", ->
      it "wraps the selection with brackets", ->
        editSession.insertText 'text\nabcd'
        editSession.moveCursorToBottom()
        editSession.selectToTop()
        editSession.selectAll()
        editSession.insertText '('
        expect('(text\nabcd)').toBe buffer.getText()
        expect(editSession.getSelectedBufferRange()).toEqual [[0, 1], [1, 4]]
        expect(editSession.getSelection().isReversed()).toBeTruthy()

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

  describe "matching bracket deletion", ->
    it "deletes the end bracket when it directly proceeds a begin bracket that is being backspaced", ->
      buffer.setText("")
      editSession.setCursorBufferPosition([0, 0])
      editSession.insertText '{'
      expect(buffer.lineForRow(0)).toBe "{}"
      editSession.backspace()
      expect(buffer.lineForRow(0)).toBe ""
