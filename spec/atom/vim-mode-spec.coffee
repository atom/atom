Editor = require 'editor'
VimMode = require 'vim-mode'

describe "VimMode", ->
  [editor, vimMode] = []

  beforeEach ->
    editor = new Editor
    editor.enableKeymap()
    vimMode = new VimMode(editor)

  describe "initialize", ->
    it "puts the editor in command-mode initially", ->
      expect(editor).toHaveClass 'command-mode'

  describe "command-mode", ->
    it "stops propagation on key events would otherwise insert a character, but allows unhandled non-insertions through", ->
      event = keydownEvent('\\')
      spyOn(event, 'stopPropagation')
      editor.trigger event
      expect(event.stopPropagation).toHaveBeenCalled()

      event = keydownEvent('/', metaKey: true)
      spyOn(event, 'stopPropagation')
      editor.trigger event
      expect(event.stopPropagation).not.toHaveBeenCalled()

    it "does not allow the cursor to be placed on the \n character, unless the line is empty", ->
      editor.buffer.setText("012345\n\nabcdef")
      editor.setCursorScreenPosition([0, 5])
      expect(editor.getCursorScreenPosition()).toEqual [0,5]

      editor.setCursorScreenPosition([0, 6])
      expect(editor.getCursorScreenPosition()).toEqual [0,5]

      editor.setCursorScreenPosition([1, 0])
      expect(editor.getCursorScreenPosition()).toEqual [1,0]

    it "clears the operator stack when commands can't be composed", ->
      editor.trigger keydownEvent('d')
      expect(vimMode.opStack.length).toBe 1
      editor.trigger keydownEvent('x')
      expect(vimMode.opStack.length).toBe 0

      editor.trigger keydownEvent('d')
      expect(vimMode.opStack.length).toBe 1
      editor.trigger keydownEvent('\\') # \ is an unused key in vim
      expect(vimMode.opStack.length).toBe 0

    describe "the escape keybinding", ->
      it "clears the operator stack", ->
        editor.trigger keydownEvent('d')
        expect(vimMode.opStack.length).toBe 1

        editor.trigger keydownEvent('escape')
        expect(vimMode.opStack.length).toBe 0

    describe "the i keybinding", ->
      it "puts the editor into insert mode", ->
        expect(editor).not.toHaveClass 'insert-mode'

        editor.trigger keydownEvent('i')

        expect(editor).toHaveClass 'insert-mode'
        expect(editor).not.toHaveClass 'command-mode'

    describe "the x keybinding", ->
      it "deletes a charachter", ->
        editor.buffer.setText("012345")
        editor.setCursorScreenPosition([0, 4])

        editor.trigger keydownEvent('x')
        expect(editor.buffer.getText()).toBe '01235'
        expect(editor.getCursorScreenPosition()).toEqual([0, 4])

        editor.trigger keydownEvent('x')
        expect(editor.buffer.getText()).toBe '0123'
        expect(editor.getCursorScreenPosition()).toEqual([0, 3])

        editor.trigger keydownEvent('x')
        expect(editor.buffer.getText()).toBe '012'
        expect(editor.getCursorScreenPosition()).toEqual([0, 2])

      it "deletes nothing when cursor is on empty line", ->
        editor.buffer.setText "012345\n\nabcdef"
        editor.setCursorScreenPosition [1, 0]

        editor.trigger keydownEvent 'x'
        expect(editor.buffer.getText()).toBe "012345\n\nabcdef"

    describe "the d keybinding", ->
      describe "when followed by a d", ->
        it "deletes the current line", ->
          editor.buffer.setText("12345\nabcde\nABCDE")
          editor.setCursorScreenPosition([1,1])

          editor.trigger keydownEvent('d')
          editor.trigger keydownEvent('d')
          expect(editor.buffer.getText()).toBe "12345\nABCDE"
          expect(editor.getCursorScreenPosition()).toEqual([1,0])

        it "deletes the last line", ->
          editor.buffer.setText("12345\nabcde\nABCDE")
          editor.setCursorScreenPosition([2,1])
          editor.trigger keydownEvent('d')
          editor.trigger keydownEvent('d')
          expect(editor.buffer.getText()).toBe "12345\nabcde"
          expect(editor.getCursorScreenPosition()).toEqual([1,0])

        xdescribe "when the second d is prefixed by a count", ->
          it "deletes n lines, starting from the current", ->
            editor.buffer.setText("12345\nabcde\nABCDE\nQWERT")
            editor.setCursorScreenPosition([1,1])

            editor.trigger keydownEvent('d')
            editor.trigger keydownEvent('2')
            editor.trigger keydownEvent('d')

            expect(editor.buffer.getText()).toBe "12345\nQWERT"
            expect(editor.getCursorScreenPosition()).toEqual([1,0])

      describe "when followed by an h", ->
        it "deletes the previous letter on the current line", ->
          editor.buffer.setText("abcd\n01234")
          editor.setCursorScreenPosition([1,1])

          editor.trigger keydownEvent 'd'
          editor.trigger keydownEvent 'h'

          expect(editor.buffer.getText()).toBe "abcd\n1234"
          expect(editor.getCursorScreenPosition()).toEqual([1,0])

          editor.trigger keydownEvent 'd'
          editor.trigger keydownEvent 'h'

          expect(editor.buffer.getText()).toBe "abcd\n1234"
          expect(editor.getCursorScreenPosition()).toEqual([1,0])

      describe "when followed by a w", ->
        it "deletes to the beginning of the next word", ->
          editor.buffer.setText("abcd efg")
          editor.setCursorScreenPosition([0,2])

          editor.trigger keydownEvent('d')
          editor.trigger keydownEvent('w')

          expect(editor.buffer.getText()).toBe "abefg"
          expect(editor.getCursorScreenPosition()).toEqual([0,2])

          editor.buffer.setText("one two three four")
          editor.setCursorScreenPosition([0,0])

          editor.trigger keydownEvent('d')
          editor.trigger keydownEvent('3')
          editor.trigger keydownEvent('w')

          expect(editor.buffer.getText()).toBe "four"
          expect(editor.getCursorScreenPosition()).toEqual([0,0])

      describe "when followed by a b", ->
        it "deletes to the beginning of the previous word", ->
          editor.buffer.setText("abcd efg")
          editor.setCursorScreenPosition([0,2])

          editor.trigger keydownEvent('d')
          editor.trigger keydownEvent('b')

          expect(editor.buffer.getText()).toBe "cd efg"
          expect(editor.getCursorScreenPosition()).toEqual([0,0])

          editor.buffer.setText("one two three four")
          editor.setCursorScreenPosition([0,11])

          editor.trigger keydownEvent('d')
          editor.trigger keydownEvent('3')
          editor.trigger keydownEvent('b')

          expect(editor.buffer.getText()).toBe "ee four"
          expect(editor.getCursorScreenPosition()).toEqual([0,0])

    describe "basic motion bindings", ->
      beforeEach ->
        editor.buffer.setText("12345\nabcde\nABCDE")
        editor.setCursorScreenPosition([1,1])

      describe "the h keybinding", ->
        it "moves the cursor left, but not to the previous line", ->
          editor.trigger keydownEvent('h')
          expect(editor.getCursorScreenPosition()).toEqual([1,0])
          editor.trigger keydownEvent('h')
          expect(editor.getCursorScreenPosition()).toEqual([1,0])

      describe "the j keybinding", ->
        it "moves the cursor down, but not to the end of the last line", ->
          editor.trigger keydownEvent 'j'
          expect(editor.getCursorScreenPosition()).toEqual([2,1])
          editor.trigger keydownEvent 'j'
          expect(editor.getCursorScreenPosition()).toEqual([2,1])

      describe "the k keybinding", ->
        it "moves the cursor up, but not to the beginning of the first line", ->
          editor.trigger keydownEvent('k')
          expect(editor.getCursorScreenPosition()).toEqual([0,1])
          editor.trigger keydownEvent('k')
          expect(editor.getCursorScreenPosition()).toEqual([0,1])

      describe "the l keybinding", ->
        it "moves the cursor right, but not to the next line", ->
          editor.setCursorScreenPosition([1,3])
          editor.trigger keydownEvent('l')
          expect(editor.getCursorScreenPosition()).toEqual([1,4])
          editor.trigger keydownEvent('l')
          expect(editor.getCursorScreenPosition()).toEqual([1,4])

      describe "the w keybinding", ->
        it "moves the cursor to the beginning of the next word", ->
          editor.buffer.setText("ab cde1+- \n xyz\n\nzip")
          editor.setCursorScreenPosition([0,0])

          editor.trigger keydownEvent('w')
          expect(editor.getCursorScreenPosition()).toEqual([0,3])

          editor.trigger keydownEvent('w')
          expect(editor.getCursorScreenPosition()).toEqual([0,7])

          editor.trigger keydownEvent('w')
          expect(editor.getCursorScreenPosition()).toEqual([1,1])

          editor.trigger keydownEvent('w')
          expect(editor.getCursorScreenPosition()).toEqual([2,0])

          editor.trigger keydownEvent('w')
          expect(editor.getCursorScreenPosition()).toEqual([3,0])

          editor.trigger keydownEvent('w')
          expect(editor.getCursorScreenPosition()).toEqual([3,2])

      describe "the { keybinding", ->
        it "moves the cursor to the beginning of the paragraph", ->
          editor.buffer.setText("abcde\n\nfghij\nhijk\n  xyz  \n\nzip\n\n  \nthe end")
          editor.setCursorScreenPosition([0,0])

          editor.trigger keydownEvent('}')
          expect(editor.getCursorScreenPosition()).toEqual [1,0]

          editor.trigger keydownEvent('}')
          expect(editor.getCursorScreenPosition()).toEqual [5,0]

          editor.trigger keydownEvent('}')
          expect(editor.getCursorScreenPosition()).toEqual [7,0]

          editor.trigger keydownEvent('}')
          expect(editor.getCursorScreenPosition()).toEqual [9,6]

      describe "the b keybinding", ->
        it "moves the cursor to the beginning of the previous word", ->
          editor.buffer.setText(" ab cde1+- \n xyz\n\nzip }\n last")
          editor.setCursorScreenPosition [4,1]

          editor.trigger keydownEvent('b')
          expect(editor.getCursorScreenPosition()).toEqual [3,4]

          editor.trigger keydownEvent('b')
          expect(editor.getCursorScreenPosition()).toEqual [3,0]

          editor.trigger keydownEvent('b')
          expect(editor.getCursorScreenPosition()).toEqual [2,0]

          editor.trigger keydownEvent('b')
          expect(editor.getCursorScreenPosition()).toEqual [1,1]

          editor.trigger keydownEvent('b')
          expect(editor.getCursorScreenPosition()).toEqual [0,8]

          editor.trigger keydownEvent('b')
          expect(editor.getCursorScreenPosition()).toEqual [0,4]

          editor.trigger keydownEvent('b')
          expect(editor.getCursorScreenPosition()).toEqual [0,1]

          editor.trigger keydownEvent('b')
          expect(editor.getCursorScreenPosition()).toEqual [0,0]

          editor.trigger keydownEvent('b')
          expect(editor.getCursorScreenPosition()).toEqual [0,0]

    describe "numeric prefix bindings", ->
      it "repeats the following operation N times", ->
        editor.buffer.setText("12345")
        editor.setCursorScreenPosition([0,1])

        editor.trigger keydownEvent('3')
        editor.trigger keydownEvent('x')

        expect(editor.buffer.getText()).toBe '15'

        editor.buffer.setText("123456789abc")
        editor.setCursorScreenPosition([0,0])
        editor.trigger keydownEvent('1')
        editor.trigger keydownEvent('0')
        editor.trigger keydownEvent('x')

        expect(editor.buffer.getText()).toBe 'bc'

  describe "insert-mode", ->
    beforeEach ->
      editor.trigger keydownEvent('i')

    it "allows the cursor to reach the end of the line", ->
      editor.buffer.setText("012345\n\nabcdef")
      editor.setCursorScreenPosition([0, 5])
      expect(editor.getCursorScreenPosition()).toEqual [0,5]

      editor.setCursorScreenPosition([0, 6])
      expect(editor.getCursorScreenPosition()).toEqual [0,6]

    it "puts the editor into command mode when <escape> is pressed", ->
      expect(editor).not.toHaveClass 'command-mode'

      editor.trigger keydownEvent('escape')

      expect(editor).toHaveClass 'command-mode'
      expect(editor).not.toHaveClass 'insert-mode'
