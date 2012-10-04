EditorCommand = require 'editor-command'
LowerCaseCommand = require 'lowercase-command'
UpperCaseCommand = require 'uppercase-command'
RootView = require 'root-view'
fs = require 'fs'

describe "EditorCommand", ->
  [rootView, editor, path] = []

  beforeEach ->
    rootView = new RootView
    rootView.open(require.resolve 'fixtures/sample.js')

    rootView.focus()
    editor = rootView.getActiveEditor()

  afterEach ->
    rootView.remove()

  describe "@alterSelection()", ->
    it "returns true when transformed text is non-empty", ->
      transformed = false
      altered = false
      class CustomCommand extends EditorCommand
        @getKeymaps: (editor) ->
          'meta-V': 'custom'

        @execute: (editor, event) ->
          altered = @alterSelection editor, (text) ->
            transformed = true
            'new'

      CustomCommand.activate(rootView)
      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      editor.trigger 'custom'
      expect(transformed).toBe true
      expect(altered).toBe true

    it "returns false when transformed text is null", ->
      transformed = false
      altered = false
      class CustomCommand extends EditorCommand
        @getKeymaps: (editor) ->
          'meta-V': 'custom'

        @execute: (editor, event) ->
          altered = @alterSelection editor, (text) ->
            transformed = true
            null

      CustomCommand.activate(rootView)
      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      editor.trigger 'custom'
      expect(transformed).toBe true
      expect(altered).toBe false

    it "returns false when transformed text is undefined", ->
      transformed = false
      altered = false
      class CustomCommand extends EditorCommand
        @getKeymaps: (editor) ->
          'meta-V': 'custom'

        @execute: (editor, event) ->
          altered = @alterSelection editor, (text) ->
            transformed = true
            undefined

      CustomCommand.activate(rootView)
      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      editor.trigger 'custom'
      expect(transformed).toBe true
      expect(altered).toBe false

  describe "custom sub-class", ->
    it "removes vowels from selected text", ->
      class VowelRemover extends EditorCommand
        @getKeymaps: (editor) ->
          'meta-V': 'devowel'

        @execute: (editor, event) ->
          @alterSelection editor, (text) ->
            text.replace(/[aeiouy]/gi, '')

      VowelRemover.activate(rootView)
      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      editor.trigger 'devowel'
      expect(editor.lineForBufferRow(0)).toBe 'vr qcksrt = fnctn () {'
      expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'vr qcksrt = fnctn () {'

    it "doesn't transform empty selections", ->
       callbackCount = 0
       class CustomCommand extends EditorCommand
         @getKeymaps: (editor) ->
           'meta-V': 'custom'

         @execute: (editor, event) ->
           @alterSelection editor, (text) ->
             callbackCount++
             text

       CustomCommand.activate(rootView)
       editor.moveCursorToTop()
       editor.selectToEndOfLine()
       editor.trigger 'custom'
       expect(callbackCount).toBe 1
       editor.clearSelections()
       editor.trigger 'custom'
       expect(callbackCount).toBe 1

    it "registers all keymaps", ->
      callbackCount = 0
      class CustomCommand extends EditorCommand
        @getKeymaps: (editor) ->
          'meta-V': 'custom1'
          'meta-B': 'custom2'

        @execute: (editor, event) ->
          @alterSelection editor, (text) ->
            callbackCount++
            text

        CustomCommand.activate(rootView)
        editor.moveCursorToTop()
        editor.selectToEndOfLine()
        editor.trigger 'custom1'
        expect(callbackCount).toBe 1
        editor.trigger 'custom2'
        expect(callbackCount).toBe 2

  describe "LowerCaseCommand", ->
    it "replaces the selected text with all lower case characters", ->
      LowerCaseCommand.activate(rootView)
      editor.setSelectedBufferRange([[11,14], [11,19]])
      expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'Array'
      editor.trigger 'lowercase'
      expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'array'


  describe "UpperCaseCommand", ->
    it "replaces the selected text with all upper case characters", ->
      UpperCaseCommand.activate(rootView)
      editor.setSelectedBufferRange([[0,0], [0,3]])
      expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'var'
      editor.trigger 'uppercase'
      expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'VAR'
