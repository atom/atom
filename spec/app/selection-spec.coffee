Buffer = require 'buffer'
EditSession = require 'edit-session'
Range = require 'range'

describe "Selection", ->
  [buffer, editSession, selection] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    editSession = new EditSession(buffer: buffer, tabText: '  ')
    selection = editSession.getSelection()

  afterEach ->
    buffer.destroy()

  describe ".deleteSelectedText()", ->
    describe "when nothing is selected", ->
      it "deletes nothing", ->
        selection.setBufferRange new Range([0,3], [0,3])
        selection.deleteSelectedText()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

    describe "when one line is selected", ->
      it "deletes selected text and clears the selection", ->
        selection.setBufferRange new Range([0,4], [0,14])
        selection.deleteSelectedText()
        expect(buffer.lineForRow(0)).toBe "var = function () {"

        endOfLine = buffer.lineForRow(0).length
        selection.setBufferRange new Range([0,0], [0, endOfLine])
        selection.deleteSelectedText()
        expect(buffer.lineForRow(0)).toBe ""

        expect(selection.isEmpty()).toBeTruthy()

    describe "when multiple lines are selected", ->
      it "deletes selected text and clears the selection", ->
        selection.setBufferRange new Range([0,1], [2,39])
        selection.deleteSelectedText()
        expect(buffer.lineForRow(0)).toBe "v;"
        expect(selection.isEmpty()).toBeTruthy()

    describe "when the cursor precedes the anchor", ->
      it "it deletes selected text and clears the selection", ->
        selection.cursor.setScreenPosition [0,13]
        selection.selectToScreenPosition [0,4]

        selection.delete()
        expect(buffer.lineForRow(0)).toBe "var  = function () {"
        expect(selection.isEmpty()).toBeTruthy()

  describe ".isReversed()", ->
    it "returns true if the cursor precedes the anchor", ->
      selection.cursor.setScreenPosition([0, 20])
      selection.selectToScreenPosition([0, 10])
      expect(selection.isReversed()).toBeTruthy()

      selection.selectToScreenPosition([0, 25])
      expect(selection.isReversed()).toBeFalsy()

  describe "when only the selection's anchor is moved (regression)", ->
    it "emits the 'change-screen-range' event", ->
      selection.setBufferRange([[2, 0], [2, 10]], reverse: true)
      changeScreenRangeHandler = jasmine.createSpy('changeScreenRangeHandler')
      selection.on 'change-screen-range', changeScreenRangeHandler

      buffer.insert([2, 5], 'abc')
      expect(changeScreenRangeHandler).toHaveBeenCalled()

  describe "when the selection is destroyed", ->
    it "destroys its cursor and its anchor's cursor", ->
      selection.setBufferRange([[2, 0], [2, 10]])

      selection.destroy()

      expect(editSession.getAnchors().indexOf(selection.anchor)).toBe -1
      expect(editSession.getAnchors().indexOf(selection.cursor.anchor)).toBe -1
