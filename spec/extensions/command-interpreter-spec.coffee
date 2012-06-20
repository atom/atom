CommandInterpreter = require 'command-interpreter'
Buffer = require 'buffer'
EditSession = require 'edit-session'
Editor = require 'editor'

describe "CommandInterpreter", ->
  [interpreter, editor, buffer] = []

  beforeEach ->
    editSession = fixturesProject.open('sample.js')
    buffer = editSession.buffer
    editor = new Editor(editSession: editSession)
    interpreter = new CommandInterpreter()

  describe "addresses", ->
    beforeEach ->
      editor.addSelectionForBufferRange([[7,0], [7,11]])
      editor.addSelectionForBufferRange([[8,0], [8,11]])

    describe "a line address", ->
      it "selects the specified line", ->
        interpreter.eval(editor, '4')
        expect(editor.getSelections().length).toBe 1
        expect(editor.getSelection().getBufferRange()).toEqual [[3, 0], [4, 0]]

    describe "0", ->
      it "selects the zero-length string at the start of the file", ->
        interpreter.eval(editor, '0')
        expect(editor.getSelections().length).toBe 1
        expect(editor.getSelection().getBufferRange()).toEqual [[0,0], [0,0]]

        interpreter.eval(editor, '0,1')
        expect(editor.getSelections().length).toBe 1
        expect(editor.getSelection().getBufferRange()).toEqual [[0,0], [1,0]]

    describe "$", ->
      it "selects EOF", ->
        interpreter.eval(editor, '$')
        expect(editor.getSelections().length).toBe 1
        expect(editor.getSelection().getBufferRange()).toEqual [[12,2], [12,2]]

        interpreter.eval(editor, '1,$')
        expect(editor.getSelections().length).toBe 1
        expect(editor.getSelection().getBufferRange()).toEqual [[0,0], [12,2]]

    describe ".", ->
      describe "when a single selection", ->
        it 'maintains the current selection', ->
          editor.clearSelections()
          editor.setSelectedBufferRange([[1,1], [2,2]])
          interpreter.eval(editor, '.')
          expect(editor.getSelection().getBufferRange()).toEqual [[1,1], [2,2]]

          editor.setSelectedBufferRange([[1,1], [2,2]])
          interpreter.eval(editor, '.,')
          expect(editor.getSelection().getBufferRange()).toEqual [[1,1], [12,2]]

          editor.setSelectedBufferRange([[1,1], [2,2]])
          interpreter.eval(editor, ',.')
          expect(editor.getSelection().getBufferRange()).toEqual [[0,0], [2,2]]

      describe "with multiple selections", ->
        it "maintains the current selections", ->
          preSelections = editor.getSelections()
          expect(preSelections.length).toBe 3
          [preRange1, preRange2, preRange3] = preSelections.map (s) -> s.getScreenRange()

          interpreter.eval(editor, '.')

          selections = editor.getSelections()
          expect(selections.length).toBe 3
          [selection1, selection2, selection3] = selections
          expect(selection1.getScreenRange()).toEqual preRange1
          expect(selection2.getScreenRange()).toEqual preRange2
          expect(selection3.getScreenRange()).toEqual preRange3

    describe "/regex/", ->
      beforeEach ->
        editor.clearSelections()

      it 'selects text matching regex after current selection', ->
        editor.setSelectedBufferRange([[4,16], [4,20]])
        interpreter.eval(editor, '/pivot/')
        expect(editor.getSelection().getBufferRange()).toEqual [[6,16], [6,21]]

      it 'does not require the trailing slash', ->
        editor.setSelectedBufferRange([[4,16], [4,20]])
        interpreter.eval(editor, '/pivot')
        expect(editor.getSelection().getBufferRange()).toEqual [[6,16], [6,21]]

      it "searches from the end of each selection in the buffer", ->
        editor.clearSelections()
        editor.setSelectedBufferRange([[4,16], [4,20]])
        editor.addSelectionForBufferRange([[1,16], [2,20]])
        expect(editor.getSelections().length).toBe 2
        interpreter.eval(editor, '/pivot')
        selections = editor.getSelections()
        expect(selections.length).toBe 2
        expect(selections[0].getBufferRange()).toEqual [[3,8], [3,13]]
        expect(selections[1].getBufferRange()).toEqual [[6,16], [6,21]]

      it "wraps around to the beginning of the buffer, but doesn't infinitely loop if no matches are found", ->
        editor.setSelectedBufferRange([[10, 0], [10,3]])
        interpreter.eval(editor, '/pivot')
        expect(editor.getSelection().getBufferRange()).toEqual [[3,8], [3,13]]

        interpreter.eval(editor, '/mike tyson')
        expect(editor.getSelection().getBufferRange()).toEqual [[3,8], [3,13]]

      it "searches in reverse when prefixed with a -", ->
        editor.setSelectedBufferRange([[6, 16], [6, 22]])
        interpreter.eval(editor, '-/pivot')
        expect(editor.getSelection().getBufferRange()).toEqual [[3,8], [3,13]]

    describe "address range", ->
      describe "when two addresses are specified", ->
        it "selects from the begining of the left address to the end of the right address", ->
          interpreter.eval(editor, '4,7')
          expect(editor.getSelections().length).toBe 1
          expect(editor.getSelection().getBufferRange()).toEqual [[3, 0], [7, 0]]

      describe "when the left address is unspecified", ->
        it "selects from the begining of buffer to the end of the right address", ->
          interpreter.eval(editor, ',7')
          expect(editor.getSelections().length).toBe 1
          expect(editor.getSelection().getBufferRange()).toEqual [[0, 0], [7, 0]]

      describe "when the right address is unspecified", ->
        it "selects from the begining of left address to the end file", ->
          interpreter.eval(editor, '4,')
          expect(editor.getSelections().length).toBe 1
          expect(editor.getSelection().getBufferRange()).toEqual [[3, 0], [12, 2]]

      describe "when the neither address is specified", ->
        it "selects the entire file", ->
          interpreter.eval(editor, ',')
          expect(editor.getSelections().length).toBe 1
          expect(editor.getSelection().getBufferRange()).toEqual [[0, 0], [12, 2]]

  describe "x/regex/", ->
    it "sets the current selection to every match of the regex in the current selection", ->
      interpreter.eval(editor, '6,7 x/current/')

      selections = editor.getSelections()
      expect(selections.length).toBe 4

      expect(selections[0].getBufferRange()).toEqual [[5,6], [5,13]]
      expect(selections[1].getBufferRange()).toEqual [[6,6], [6,13]]
      expect(selections[2].getBufferRange()).toEqual [[6,34], [6,41]]
      expect(selections[3].getBufferRange()).toEqual [[6,56], [6,63]]

    describe "when matching /$/", ->
      it "matches the end of each line in the selected region", ->
        interpreter.eval(editor, '6,8 x/$/')

        cursors = editor.getCursors()
        expect(cursors.length).toBe 3

        expect(cursors[0].getBufferPosition()).toEqual [5, 30]
        expect(cursors[1].getBufferPosition()).toEqual [6, 65]
        expect(cursors[2].getBufferPosition()).toEqual [7, 5]

    it "loops through current selections and selects text matching the regex", ->
      editor.setSelectedBufferRange [[3,0], [3,62]]
      editor.addSelectionForBufferRange [[6,0], [6,65]]

      interpreter.eval(editor, 'x/current')

      selections = editor.getSelections()
      expect(selections.length).toBe 4

      expect(selections[0].getBufferRange()).toEqual [[3,31], [3,38]]
      expect(selections[1].getBufferRange()).toEqual [[6,6], [6,13]]
      expect(selections[2].getBufferRange()).toEqual [[6,34], [6,41]]
      expect(selections[3].getBufferRange()).toEqual [[6,56], [6,63]]

  describe "substitution", ->
    it "does nothing if there are no matches", ->
      editor.setSelectedBufferRange([[6, 0], [6, 44]])
      interpreter.eval(editor, 's/not-in-text/foo/')
      expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(current) : right.push(current);'

    describe "when not global", ->
      describe "when there is a single selection", ->
        it "performs a single substitution within the current selection", ->
          editor.setSelectedBufferRange([[6, 0], [6, 44]])
          interpreter.eval(editor, 's/current/foo/')
          expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(current) : right.push(current);'

      describe "when there are multiple selections", ->
        it "performs a single substitutions within each of the selections", ->
          editor.setSelectedBufferRange([[5, 0], [5, 20]])
          editor.addSelectionForBufferRange([[6, 0], [6, 44]])

          interpreter.eval(editor, 's/current/foo/')
          expect(buffer.lineForRow(5)).toBe '      foo = items.shift();'
          expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(current) : right.push(current);'

    describe "when global", ->
      it "performs a multiple substitutions within the current selection", ->
        editor.setSelectedBufferRange([[6, 0], [6, 44]])
        interpreter.eval(editor, 's/current/foo/g')
        expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(foo) : right.push(current);'

      describe "when prefixed with an address", ->
        it "only makes substitutions within given lines", ->
          interpreter.eval(editor, '4,6s/ /!/g')
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(3)).toBe '!!!!var!pivot!=!items.shift(),!current,!left!=![],!right!=![];'
          expect(buffer.lineForRow(4)).toBe '!!!!while(items.length!>!0)!{'
          expect(buffer.lineForRow(5)).toBe '!!!!!!current!=!items.shift();'
          expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(current) : right.push(current);'

      describe "when matching $", ->
        it "matches the end of each line and avoids infinitely looping on a zero-width match", ->
          interpreter.eval(editor, ',s/$/!!!/g')
          expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {!!!'
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;!!!'
          expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(current) : right.push(current);!!!'
          expect(buffer.lineForRow(12)).toBe '};!!!'

      describe "when matching ^", ->
        it "matches the beginning of each line and avoids infinitely looping on a zero-width match", ->
          interpreter.eval(editor, ',s/^/!!!/g')
          expect(buffer.lineForRow(0)).toBe '!!!var quicksort = function () {'
          expect(buffer.lineForRow(2)).toBe '!!!    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(6)).toBe '!!!      current < pivot ? left.push(current) : right.push(current);'
          expect(buffer.lineForRow(12)).toBe '!!!};'

      describe "when there are multiple selections", ->
        it "performs a multiple substitutions within each of the selections", ->
          editor.setSelectedBufferRange([[5, 0], [5, 20]])
          editor.addSelectionForBufferRange([[6, 0], [6, 44]])

          interpreter.eval(editor, 's/current/foo/g')
          expect(buffer.lineForRow(5)).toBe '      foo = items.shift();'
          expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(foo) : right.push(current);'

  describe "when command selects folded text", ->
    it "unfolds lines that command selects", ->
      editor.createFold(1, 9)
      editor.createFold(5, 8)
      editor.setSelectedBufferRange([[0,0], [0,0]])

      interpreter.eval(editor, '/push/')
      expect(editor.getSelection().getBufferRange()).toEqual [[6,29], [6,33]]
      expect(editor.lineForScreenRow(1).fold).toBeUndefined()
      expect(editor.lineForScreenRow(5).fold).toBeUndefined()
      expect(editor.lineForScreenRow(6).text).toBe buffer.lineForRow(6)
