Editor = require 'editor'
VimMode = require 'vim-mode'

describe "VimMode", ->
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
        editor.setCursor(column: 1, row: 0)

        editor.trigger keydownEvent('x')

        expect(editor.buffer.getText()).toBe '1345'
        expect(editor.getCursor()).toEqual(column: 1, row: 0)

    describe "the d keybinding", ->
      it "deletes the line the cursor is on when 'd' is pressed again", ->
        editor.buffer.setText("12345\nabcde\nABCDE")
        editor.setCursor(column: 1, row: 1)
        spyOn(editor, 'deleteLine').andCallThrough()

        editor.trigger keydownEvent('d')
        editor.trigger keydownEvent('d')

        expect(editor.deleteLine).toHaveBeenCalled()
        expect(editor.buffer.getText()).toBe "12345\nABCDE"
        expect(editor.getCursor()).toEqual(column: 0, row: 1)

    describe "basic motion bindings", ->
      beforeEach ->
        editor.buffer.setText("12345\nabcde\nABCDE")
        editor.setCursor(column: 1, row: 1)

      describe "the h keybinding", ->
        it "move the cursor left", ->
          editor.trigger keydownEvent('h')
          expect(editor.getCursor()).toEqual(column: 0, row: 1)
          editor.trigger keydownEvent('h')
          expect(editor.getCursor()).toEqual(column: 0, row: 1)

      describe "the j keybinding", ->
        it "move the cursor up", ->
          editor.trigger keydownEvent('j')
          expect(editor.getCursor()).toEqual(column: 1, row: 0)
          editor.trigger keydownEvent('j')
          expect(editor.getCursor()).toEqual(column: 1, row: 0)

    describe "numeric prefix bindings", ->
      it "repeats the following operation N times", ->
        editor.buffer.setText("12345")
        editor.setCursor(column: 1, row: 0)

        editor.trigger keydownEvent('3')
        editor.trigger keydownEvent('x')

        expect(editor.buffer.getText()).toBe '15'

        editor.buffer.setText("123456789abc")
        editor.setCursor(column: 0, row: 0)
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
