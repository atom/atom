Buffer = require 'buffer'
Editor = require 'editor'
Range = require 'range'

describe "Selection", ->
  [editor, buffer, selection] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    editor = Editor.build()
    editor.enableKeymap()
    editor.setBuffer(buffer)
    selection = editor.selection

  describe ".setRange(range)", ->
    it "places the anchor at the start of the range and the cursor at the end", ->
      range = new Range({row: 2, column: 7}, {row: 3, column: 18})
      selection.setRange(range)
      expect(selection.anchor.getPosition()).toEqual range.start
      expect(selection.cursor.getPosition()).toEqual range.end

  describe ".delete()", ->
    describe "when nothing is selected", ->
      it "deletes nothing", ->
        selection.setRange new Range([0,3], [0,3])
        selection.delete()
        expect(editor.buffer.getLine(0)).toBe "var quicksort = function () {"

    describe "when one line is selected", ->
      it "deletes selected text", ->
        selection.setRange new Range([0,4], [0,14])
        selection.delete()
        expect(editor.buffer.getLine(0)).toBe "var = function () {"

        endOfLine = editor.buffer.getLine(0).length
        selection.setRange new Range([0,0], [0, endOfLine])
        selection.delete()
        expect(editor.buffer.getLine(0)).toBe ""

    describe "when multiple lines are selected", ->
      it "deletes selected text", ->
        selection.setRange new Range([0,1], [2,39])
        selection.delete()
        expect(editor.buffer.getLine(0)).toBe "v;"

  describe ".updateAppearence()", ->
    [charWidth, lineHeight] = []

    beforeEach ->
      editor.attachToDom()
      editor.width(500)
      { charWidth, lineHeight } = editor

    describe "when the selection is within a single line", ->
      it "covers the selection's range with a single region", ->
        selection.setRange(new Range({row: 2, column: 7}, {row: 2, column: 25}))

        expect(selection.regions.length).toBe 1
        region = selection.regions[0]
        expect(region.position().top).toBe(2 * lineHeight)
        expect(region.position().left).toBe(7 * charWidth)
        expect(region.height()).toBe lineHeight
        expect(region.width()).toBe((25 - 7) * charWidth)

    describe "when the selection spans 2 lines", ->
      it "covers the selection's range with 2 regions", ->
        selection.setRange(new Range({row: 2, column: 7}, {row: 3, column: 25}))

        expect(selection.regions.length).toBe 2

        region1 = selection.regions[0]
        expect(region1.position().top).toBe(2 * lineHeight)
        expect(region1.position().left).toBe(7 * charWidth)
        expect(region1.height()).toBe lineHeight
        expect(region1.width()).toBe(editor.width() - region1.position().left)

        region2 = selection.regions[1]
        expect(region2.position().top).toBe(3 * lineHeight)
        expect(region2.position().left).toBe(0)
        expect(region2.height()).toBe lineHeight
        expect(region2.width()).toBe(25 * charWidth)

    describe "when the selection spans more than 2 lines", ->
      it "covers the selection's range with 3 regions", ->
        selection.setRange(new Range({row: 2, column: 7}, {row: 6, column: 25}))

        expect(selection.regions.length).toBe 3

        region1 = selection.regions[0]
        expect(region1.position().top).toBe(2 * lineHeight)
        expect(region1.position().left).toBe(7 * charWidth)
        expect(region1.height()).toBe lineHeight
        expect(region1.width()).toBe(editor.width() - region1.position().left)

        region2 = selection.regions[1]
        expect(region2.position().top).toBe(3 * lineHeight)
        expect(region2.position().left).toBe(0)
        expect(region2.height()).toBe(3 * lineHeight)
        expect(region2.width()).toBe(editor.width())

        # resizes with the editor
        expect(editor.width()).toBeLessThan(800)
        editor.width(800)
        expect(region2.width()).toBe(editor.width())

        region3 = selection.regions[2]
        expect(region3.position().top).toBe(6 * lineHeight)
        expect(region3.position().left).toBe(0)
        expect(region3.height()).toBe lineHeight
        expect(region3.width()).toBe(25 * charWidth)

    it "clears previously drawn regions before creating new ones", ->
      selection.setRange(new Range({row: 2, column: 7}, {row: 4, column: 25}))
      expect(selection.regions.length).toBe 3
      expect(selection.find('.selection').length).toBe 3

      selection.updateAppearance()
      expect(selection.regions.length).toBe 3
      expect(selection.find('.selection').length).toBe 3

  describe "when a copy event is triggered", ->
    beforeEach ->
      atom.native.writeToPasteboard('first')
      expect(atom.native.readFromPasteboard()).toBe 'first'

    it "places selected text on the clipboard", ->
      selection.setRange new Range([0,4], [0,13])
      selection.copy()
      expect(atom.native.readFromPasteboard()).toBe 'quicksort'

      selection.setRange new Range([0,4], [3,13])
      selection.copy()
      expect(atom.native.readFromPasteboard()).toBe "quicksort = function () {\n  var sort = function(items) {\n    if (items.length <= 1) return items;\n    var pivot"

    it "places nothing on the clipboard when there is no selection", ->
      selection.setRange new Range([0,4], [0,4])
      selection.copy()
      expect(atom.native.readFromPasteboard()).toBe 'first'



