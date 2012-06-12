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

  describe ".setBufferRange(range)", ->
    it "places the anchor at the start of the range and the cursor at the end", ->
      range = new Range({row: 2, column: 7}, {row: 3, column: 18})
      selection.setBufferRange(range)
      expect(selection.anchor.getScreenPosition()).toEqual range.start
      expect(selection.cursor.getScreenPosition()).toEqual range.end

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

  describe ".updateAppearence()", ->
    [charWidth, lineHeight] = []

    beforeEach ->
      editor.attachToDom()
      editor.width(500)
      { charWidth, lineHeight } = editor

    describe "when the selection is within a single line", ->
      it "covers the selection's range with a single region", ->
        selection.setBufferRange(new Range({row: 2, column: 7}, {row: 2, column: 25}))

        expect(selectionView.regions.length).toBe 1
        region = selectionView.regions[0]
        expect(region.position().top).toBe(2 * lineHeight)
        expect(region.position().left).toBe(7 * charWidth)
        expect(region.height()).toBe lineHeight
        expect(region.width()).toBe((25 - 7) * charWidth)

    describe "when the selection spans 2 lines", ->
      it "covers the selection's range with 2 regions", ->
        selection.setBufferRange(new Range({row: 2, column: 7}, {row: 3, column: 25}))

        expect(selectionView.regions.length).toBe 2

        region1 = selectionView.regions[0]
        expect(region1.position().top).toBe(2 * lineHeight)
        expect(region1.position().left).toBe(7 * charWidth)
        expect(region1.height()).toBe lineHeight
        expect(region1.width()).toBe(editor.renderedLines.width() - region1.position().left)

        region2 = selectionView.regions[1]
        expect(region2.position().top).toBe(3 * lineHeight)
        expect(region2.position().left).toBe(0)
        expect(region2.height()).toBe lineHeight
        expect(region2.width()).toBe(25 * charWidth)

    describe "when the selection spans more than 2 lines", ->
      it "covers the selection's range with 3 regions", ->
        selection.setBufferRange(new Range({row: 2, column: 7}, {row: 6, column: 25}))

        expect(selectionView.regions.length).toBe 3

        region1 = selectionView.regions[0]
        expect(region1.position().top).toBe(2 * lineHeight)
        expect(region1.position().left).toBe(7 * charWidth)
        expect(region1.height()).toBe lineHeight
        expect(region1.width()).toBe(editor.renderedLines.width() - region1.position().left)

        region2 = selectionView.regions[1]
        expect(region2.position().top).toBe(3 * lineHeight)
        expect(region2.position().left).toBe(0)
        expect(region2.height()).toBe(3 * lineHeight)
        expect(region2.width()).toBe(editor.renderedLines.width())

        # resizes with the editor
        expect(editor.width()).toBeLessThan(800)
        editor.width(800)
        expect(region2.width()).toBe(editor.renderedLines.width())

        region3 = selectionView.regions[2]
        expect(region3.position().top).toBe(6 * lineHeight)
        expect(region3.position().left).toBe(0)
        expect(region3.height()).toBe lineHeight
        expect(region3.width()).toBe(25 * charWidth)

    it "clears previously drawn regions before creating new ones", ->
      selection.setBufferRange(new Range({row: 2, column: 7}, {row: 4, column: 25}))
      expect(selectionView.regions.length).toBe 3
      expect(selectionView.find('.selection').length).toBe 3

      selectionView.updateAppearance()
      expect(selectionView.regions.length).toBe 3
      expect(selectionView.find('.selection').length).toBe 3

  describe ".selectWord()", ->
     describe "when the cursor is inside a word", ->
       it "selects the entire word", ->
         editor.setCursorScreenPosition [0,8]
         selection.selectWord()
         expect(selection.getText()).toBe 'quicksort'

     describe "when the cursor is on beginning of a word", ->
       it "selects the entire word", ->
         editor.setCursorScreenPosition [0,4]
         selection.selectWord()
         expect(selection.getText()).toBe 'quicksort'

     describe "when the cursor is at the end of a word", ->
       it "selects the entire word", ->
         editor.setCursorScreenPosition [0,13]
         selection.selectWord()
         expect(selection.getText()).toBe 'quicksort'

     describe "when the cursor is not on a word", ->
       it "selects nothing", ->
         editor.setCursorScreenPosition [5,2]
         selection.selectWord()
         expect(selection.getText()).toBe ''

  describe ".isReversed()", ->
    it "returns true if the cursor precedes the anchor", ->
      selection.cursor.setScreenPosition([0, 20])
      selection.selectToScreenPosition([0, 10])
      expect(selection.isReversed()).toBeTruthy()

      selection.selectToScreenPosition([0, 25])
      expect(selection.isReversed()).toBeFalsy()

  describe ".indentSelectedRows()", ->
    tabLength = null

    beforeEach ->
      tabLength = editor.tabText.length

    describe "when nothing is selected", ->
      it "indents line and retains selection", ->
        selection.setBufferRange new Range([0,3], [0,3])
        selection.indentSelectedRows()
        expect(editor.buffer.lineForRow(0)).toBe "#{editor.tabText}var quicksort = function () {"
        expect(selection.getBufferRange()).toEqual [[0, 3 + tabLength], [0, 3 + tabLength]]

    describe "when one line is selected", ->
      it "indents line and retains selection", ->
        selection.setBufferRange new Range([0,4], [0,14])
        selection.indentSelectedRows()
        expect(editor.buffer.lineForRow(0)).toBe "#{editor.tabText}var quicksort = function () {"
        expect(selection.getBufferRange()).toEqual [[0, 4 + tabLength], [0, 14 + tabLength]]

    describe "when multiple lines are selected", ->
      it "indents selected lines (that are not empty) and retains selection", ->
        selection.setBufferRange new Range([9,1], [11,15])
        selection.indentSelectedRows()
        expect(editor.buffer.lineForRow(9)).toBe "    };"
        expect(editor.buffer.lineForRow(10)).toBe ""
        expect(editor.buffer.lineForRow(11)).toBe "    return sort(Array.apply(this, arguments));"
        expect(selection.getBufferRange()).toEqual [[9, 1 + tabLength], [11, 15 + tabLength]]

  describe ".outdentSelectedRows()", ->
    tabLength = null

    beforeEach ->
      editor.tabText = "  "
      tabLength = editor.tabText.length

    describe "when nothing is selected", ->
      it "outdents line and retains selection", ->
        selection.setBufferRange new Range([1,3], [1,3])
        selection.outdentSelectedRows()
        expect(editor.buffer.lineForRow(1)).toBe "var sort = function(items) {"
        expect(selection.getBufferRange()).toEqual [[1, 3 - tabLength], [1, 3 - tabLength]]

    describe "when one line is selected", ->
      it "outdents line and retains selection", ->
        selection.setBufferRange new Range([1,4], [1,14])
        selection.outdentSelectedRows()
        expect(editor.buffer.lineForRow(1)).toBe "var sort = function(items) {"
        expect(selection.getBufferRange()).toEqual [[1, 4 - tabLength], [1, 14 - tabLength]]

    describe "when multiple lines are selected", ->
      it "outdents selected lines and retains selection", ->
        selection.setBufferRange new Range([0,1], [3,15])
        selection.outdentSelectedRows()
        expect(editor.buffer.lineForRow(0)).toBe "var quicksort = function () {"
        expect(editor.buffer.lineForRow(1)).toBe "var sort = function(items) {"
        expect(editor.buffer.lineForRow(2)).toBe "  if (items.length <= 1) return items;"
        expect(selection.getBufferRange()).toEqual [[0, 1], [3, 15 - tabLength]]

  describe ".toggleLineComments()", ->
    it "toggles comments on the selected lines", ->
      selection.setBufferRange([[4, 5], [7, 5]])
      selection.toggleLineComments()

      expect(buffer.lineForRow(4)).toBe "//    while(items.length > 0) {"
      expect(buffer.lineForRow(5)).toBe "//      current = items.shift();"
      expect(buffer.lineForRow(6)).toBe "//      current < pivot ? left.push(current) : right.push(current);"
      expect(buffer.lineForRow(7)).toBe "//    }"

      expect(selection.getBufferRange()).toEqual [[4, 7], [7, 7]]

      selection.toggleLineComments()
      expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
      expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
      expect(buffer.lineForRow(6)).toBe "      current < pivot ? left.push(current) : right.push(current);"
      expect(buffer.lineForRow(7)).toBe "    }"

    it "preserves selection emptiness", ->
      editor.attachToDom()
      selection.setBufferRange([[4, 0], [4, 0]])
      selection.toggleLineComments()
      expect(selection.isEmpty()).toBeTruthy()
      expect(selectionView.find('.selection')).not.toExist()

  describe "when the selection ends on the begining of a fold line", ->
    beforeEach ->
      editor.createFold(2,4)
      editor.createFold(2,6)

    describe "inserting text", ->
      it "destroys the fold", ->
        selection.setBufferRange([[1,0], [2,0]])
        editor.insertText('holy cow')
        expect(editor.screenLineForRow(3).text).toBe buffer.lineForRow(3)

    describe "backspace", ->
      it "destroys the fold", ->
        selection.setBufferRange([[1,0], [2,0]])
        selection.backspace()
        expect(editor.screenLineForRow(3).text).toBe buffer.lineForRow(3)

    describe "when the selection is empty", ->
      describe "delete, when the selection is empty", ->
        it "removes the lines contained by the fold", ->
          oldLine7 = buffer.lineForRow(7)
          oldLine8 = buffer.lineForRow(8)

          selection.setBufferRange([[2, 0], [2, 0]])
          selection.delete()
          expect(editor.screenLineForRow(2).text).toBe oldLine7
          expect(editor.screenLineForRow(3).text).toBe oldLine8


  describe "auto indent/outdent", ->
    beforeEach ->
      editor.setAutoIndent(true)

    describe "when editing a line that spans a single screen line", ->
      describe "when a newline is inserted", ->
        it "indents cursor based on the indentation of previous buffer line", ->
          editor.setCursorBufferPosition([1, 30])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(2)).toEqual("    ")

      describe "when text beginning with a newline is inserted", ->
        it "indents cursor based on the indentation of previous buffer line", ->
          editor.setCursorBufferPosition([4, 29])
          editor.insertText("\nvar thisIsCool")
          expect(editor.buffer.lineForRow(5)).toEqual("      var thisIsCool")

      describe "when text that closes a scope entered", ->
        it "outdents the text", ->
          editor.setCursorBufferPosition([1, 30])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(2)).toEqual("    ")
          editor.insertText("}")
          expect(editor.buffer.lineForRow(2)).toEqual("  }")
          expect(editor.getCursorBufferPosition().column).toBe 3

      describe "when newlines are inserted for multiple cursors", ->
        it "auto-indents the newline for each cursor", ->
          editor.setCursorScreenPosition([1, 30])
          editor.addCursorAtScreenPosition([4, 29])
          editor.insertText("\n")
          expect(editor.buffer.lineForRow(2)).toEqual("    ")
          expect(editor.buffer.lineForRow(6)).toEqual("      ")
