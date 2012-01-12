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

    describe "numeric prefix binding", ->
      it "repeats the following operation N times", ->
        editor.buffer.setText("12345")
        editor.setCursor(column: 1, row: 0)

        editor.trigger keydownEvent('3')
        editor.trigger keydownEvent('x')

        expect(editor.buffer.getText()).toBe '15'

  describe "insert-mode", ->
    beforeEach ->
      editor.trigger keydownEvent('i')

    it "puts the editor into command mode when <esc> is pressed", ->
      expect(editor).not.toHaveClass 'command-mode'

      editor.trigger keydownEvent('<esc>')

      expect(editor).toHaveClass 'command-mode'
      expect(editor).not.toHaveClass 'insert-mode'
