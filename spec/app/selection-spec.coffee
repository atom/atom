Buffer = require 'buffer'
Editor = require 'editor'
Range = require 'range'

describe "Selection", ->
  [editor, buffer, selectionView, selection] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    editor = new Editor
    editor.enableKeymap()
    editor.setBuffer(buffer)
    editor.isFocused = true
    editor.attachToDom()

    selectionView = editor.getSelectionView()
    selection = editor.getSelection()

  describe ".deleteSelectedText()", ->
    describe "when nothing is selected", ->
      it "deletes nothing", ->
        selection.setBufferRange new Range([0,3], [0,3])
        selection.deleteSelectedText()
        expect(editor.buffer.lineForRow(0)).toBe "var quicksort = function () {"

    describe "when one line is selected", ->
      it "deletes selected text and clears the selection", ->
        selection.setBufferRange new Range([0,4], [0,14])
        selection.deleteSelectedText()
        expect(editor.buffer.lineForRow(0)).toBe "var = function () {"

        endOfLine = editor.buffer.lineForRow(0).length
        selection.setBufferRange new Range([0,0], [0, endOfLine])
        selection.deleteSelectedText()
        expect(editor.buffer.lineForRow(0)).toBe ""

        expect(selection.isEmpty()).toBeTruthy()

    describe "when multiple lines are selected", ->
      it "deletes selected text and clears the selection", ->
        selection.setBufferRange new Range([0,1], [2,39])
        selection.deleteSelectedText()
        expect(editor.buffer.lineForRow(0)).toBe "v;"
        expect(selection.isEmpty()).toBeTruthy()

    describe "when the cursor precedes the anchor", ->
      it "it deletes selected text and clears the selection", ->
        editor.attachToDom()
        selection.cursor.setScreenPosition [0,13]
        selection.selectToScreenPosition [0,4]

        selection.delete()
        expect(editor.buffer.lineForRow(0)).toBe "var  = function () {"
        expect(selection.isEmpty()).toBeTruthy()

        expect(selectionView.find('.selection')).not.toExist()

  describe ".isReversed()", ->
    it "returns true if the cursor precedes the anchor", ->
      selection.cursor.setScreenPosition([0, 20])
      selection.selectToScreenPosition([0, 10])
      expect(selection.isReversed()).toBeTruthy()

      selection.selectToScreenPosition([0, 25])
      expect(selection.isReversed()).toBeFalsy()

