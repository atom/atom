Editor = require 'editor'
VimMode = require 'vim-mode'

xdescribe "VimMode", ->
  editor = null

  beforeEach ->
    editor = Editor.build()
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

      event = keydownEvent('s', metaKey: true)
      spyOn(event, 'stopPropagation')
      editor.trigger event
      expect(event.stopPropagation).not.toHaveBeenCalled()


    describe "the i keybinding", ->
      it "puts the editor into insert mode", ->
        expect(editor).not.toHaveClass 'insert-mode'

        editor.trigger keydownEvent('i')

        expect(editor).toHaveClass 'insert-mode'
        expect(editor).not.toHaveClass 'command-mode'

    describe "the x keybinding", ->
      it "deletes a charachter", ->
        editor.buffer.setText("12345")
        editor.setPosition(column: 1, row: 0)

        editor.trigger keydownEvent('x')

        expect(editor.buffer.getText()).toBe '1345'
        expect(editor.getPosition()).toEqual(column: 1, row: 0)

    describe "the d keybinding", ->
      describe "when followed by a d", ->
        it "deletes the current line", ->
          editor.buffer.setText("12345\nabcde\nABCDE")
          editor.setPosition(column: 1, row: 1)

          editor.trigger keydownEvent('d')
          editor.trigger keydownEvent('d')

          expect(editor.buffer.getText()).toBe "12345\nABCDE"
          expect(editor.getPosition()).toEqual(column: 0, row: 1)

      describe "when followed by a w", ->
        it "deletes to the beginning of the next word", ->
          editor.buffer.setText("abcd efg")
          editor.setPosition(column: 2, row: 0)

          editor.trigger keydownEvent('d')
          editor.trigger keydownEvent('w')

          expect(editor.buffer.getText()).toBe "abefg"
          expect(editor.getPosition()).toEqual {column: 2, row: 0}

          editor.buffer.setText("one two three four")
          editor.setPosition(column: 0, row: 0)

          editor.trigger keydownEvent('d')
          editor.trigger keydownEvent('3')
          editor.trigger keydownEvent('w')

          expect(editor.buffer.getText()).toBe "four"
          expect(editor.getPosition()).toEqual {column: 0, row: 0}

    describe "basic motion bindings", ->
      beforeEach ->
        editor.buffer.setText("12345\nabcde\nABCDE")
        editor.setPosition(column: 1, row: 1)

      describe "the h keybinding", ->
        it "moves the cursor left, but not to the previous line", ->
          editor.trigger keydownEvent('h')
          expect(editor.getPosition()).toEqual(column: 0, row: 1)
          editor.trigger keydownEvent('h')
          expect(editor.getPosition()).toEqual(column: 0, row: 1)

      describe "the j keybinding", ->
        it "moves the cursor up, but not to the beginning of the first line", ->
          editor.trigger keydownEvent('j')
          expect(editor.getPosition()).toEqual(column: 1, row: 0)
          editor.trigger keydownEvent('j')
          expect(editor.getPosition()).toEqual(column: 1, row: 0)

      describe "the w keybinding", ->
        it "moves the cursor to the beginning of the next word", ->
          editor.buffer.setText("ab cde1+- \n xyz\n\nzip")
          editor.setPosition(column: 0, row: 0)

          editor.trigger keydownEvent('w')
          expect(editor.getPosition()).toEqual(column: 3, row: 0)

          editor.trigger keydownEvent('w')
          expect(editor.getPosition()).toEqual(column: 7, row: 0)

          editor.trigger keydownEvent('w')
          expect(editor.getPosition()).toEqual(column: 1, row: 1)

          editor.trigger keydownEvent('w')
          expect(editor.getPosition()).toEqual(column: 0, row: 2)

          editor.trigger keydownEvent('w')
          expect(editor.getPosition()).toEqual(column: 0, row: 3)

          editor.trigger keydownEvent('w')
          expect(editor.getPosition()).toEqual(column: 3, row: 3)

    describe "numeric prefix bindings", ->
      it "repeats the following operation N times", ->
        editor.buffer.setText("12345")
        editor.setPosition(column: 1, row: 0)

        editor.trigger keydownEvent('3')
        editor.trigger keydownEvent('x')

        expect(editor.buffer.getText()).toBe '15'

        editor.buffer.setText("123456789abc")
        editor.setPosition(column: 0, row: 0)
        editor.trigger keydownEvent('1')
        editor.trigger keydownEvent('0')
        editor.trigger keydownEvent('x')

        expect(editor.buffer.getText()).toBe 'bc'

  describe "insert-mode", ->
    beforeEach ->
      editor.trigger keydownEvent('i')

    it "puts the editor into command mode when <esc> is pressed", ->
      expect(editor).not.toHaveClass 'command-mode'

      editor.trigger keydownEvent('<esc>')

      expect(editor).toHaveClass 'command-mode'
      expect(editor).not.toHaveClass 'insert-mode'
