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

  describe "@replaceSelectedText()", ->
    it "returns true when transformed text is non-empty", ->
      transformed = false
      edited = false
      class CustomCommand extends EditorCommand

        @onEditor: (editor) ->
          @register editor, 'meta-V',  'custom', =>
            edited = @replaceSelectedText editor, (text) ->
              transformed = true
              'new'

      CustomCommand.activate(rootView)
      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      editor.trigger 'custom'
      expect(transformed).toBe true
      expect(edited).toBe true

    it "returns false when transformed text is null", ->
      transformed = false
      edited = false
      class CustomCommand extends EditorCommand

        @onEditor: (editor) ->
          @register editor, 'meta-V',  'custom', =>
            edited = @replaceSelectedText editor, (text) ->
              transformed = true
              null

      CustomCommand.activate(rootView)
      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      editor.trigger 'custom'
      expect(transformed).toBe true
      expect(edited).toBe false

    it "returns false when transformed text is undefined", ->
      transformed = false
      edited = false
      class CustomCommand extends EditorCommand

        @onEditor: (editor) ->
          @register editor, 'meta-V',  'custom', =>
            edited = @replaceSelectedText editor, (text) ->
              transformed = true
              undefined

      CustomCommand.activate(rootView)
      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      editor.trigger 'custom'
      expect(transformed).toBe true
      expect(edited).toBe false

  describe "custom sub-class", ->
    it "removes vowels from selected text", ->
      class VowelRemover extends EditorCommand

        @onEditor: (editor) ->
          @register editor, 'meta-V',  'devowel', =>
            @replaceSelectedText editor, (text) ->
              text.replace(/[aeiouy]/gi, '')

      VowelRemover.activate(rootView)
      editor.moveCursorToTop()
      editor.selectToEndOfLine()
      editor.trigger 'devowel'
      expect(editor.lineForBufferRow(0)).toBe 'vr qcksrt = fnctn () {'
      expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'vr qcksrt = fnctn () {'
      expect(editor.getCursorBufferPosition()).toBe(editor.getSelection().getBufferRange().end)

    it "maintains reversed selections", ->
      class VowelRemover extends EditorCommand
        @onEditor: (editor) ->
          @register editor, 'meta-V',  'devowel', =>
            @replaceSelectedText editor, (text) ->
              text.replace(/[aeiouy]/gi, '')

      VowelRemover.activate(rootView)
      editor.moveCursorToTop()
      editor.moveCursorToEndOfLine()
      editor.selectToBeginningOfLine()
      editor.trigger 'devowel'
      expect(editor.lineForBufferRow(0)).toBe 'vr qcksrt = fnctn () {'
      expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'vr qcksrt = fnctn () {'
      expect(editor.getCursorBufferPosition()).toBe(editor.getSelection().getBufferRange().start)

    it "doesn't transform empty selections", ->
       callbackCount = 0
       class CustomCommand extends EditorCommand
         @onEditor: (editor) ->
            @register editor, 'meta-V',  'custom', =>
              @replaceSelectedText editor, (text) ->
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
