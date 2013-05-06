CommandInterpreter = require 'command-panel/lib/command-interpreter'
Project = require 'project'
Buffer = require 'text-buffer'
EditSession = require 'edit-session'

_ = require 'underscore'

describe "CommandInterpreter", ->
  [interpreter, editSession, buffer] = []

  beforeEach ->
    interpreter = new CommandInterpreter(project)
    editSession = project.buildEditSession('sample.js')
    buffer = editSession.buffer

  afterEach ->
    editSession?.destroy()
    expect(buffer.getMarkerCount()).toBe 0

  describe "addresses", ->
    beforeEach ->
      editSession.addSelectionForBufferRange([[7,0], [7,11]])
      editSession.addSelectionForBufferRange([[8,0], [8,11]])

    describe "a line address", ->
      it "selects the specified line", ->
        waitsForPromise -> interpreter.eval('4', editSession)
        runs ->
          expect(editSession.getSelections().length).toBe 1
          expect(editSession.getSelection().getBufferRange()).toEqual [[3, 0], [4, 0]]

    describe "0", ->
      it "selects the zero-length string at the start of the file", ->
        waitsForPromise -> interpreter.eval('0', editSession)
        runs ->
          expect(editSession.getSelections().length).toBe 1
          expect(editSession.getSelection().getBufferRange()).toEqual [[0,0], [0,0]]

          interpreter.eval('0,1', editSession)
          expect(editSession.getSelections().length).toBe 1
          expect(editSession.getSelection().getBufferRange()).toEqual [[0,0], [1,0]]

    describe "$", ->
      it "selects EOF", ->
        waitsForPromise -> interpreter.eval('$', editSession)
        runs ->
          expect(editSession.getSelections().length).toBe 1
          expect(editSession.getSelection().getBufferRange()).toEqual [[12,2], [12,2]]

        waitsForPromise -> interpreter.eval('1,$', editSession)
        runs ->
          expect(editSession.getSelections().length).toBe 1
          expect(editSession.getSelection().getBufferRange()).toEqual [[0,0], [12,2]]

    describe ".", ->
      describe "when a single selection", ->
        it 'maintains the current selection', ->
          editSession.clearSelections()

          waitsForPromise ->
            editSession.setSelectedBufferRange([[1,1], [2,2]])
            interpreter.eval('.', editSession)

          runs ->
            expect(editSession.getSelection().getBufferRange()).toEqual [[1,1], [2,2]]

          waitsForPromise ->
            editSession.setSelectedBufferRange([[1,1], [2,2]])
            interpreter.eval('.,', editSession)

          runs ->
            expect(editSession.getSelection().getBufferRange()).toEqual [[1,1], [12,2]]

          waitsForPromise ->
            editSession.setSelectedBufferRange([[1,1], [2,2]])
            interpreter.eval(',.', editSession)

          runs ->
            expect(editSession.getSelection().getBufferRange()).toEqual [[0,0], [2,2]]

      describe "with multiple selections", ->
        it "maintains the current selections", ->
          preSelections = editSession.getSelections()
          expect(preSelections.length).toBe 3
          [preRange1, preRange2, preRange3] = preSelections.map (s) -> s.getScreenRange()

          waitsForPromise -> interpreter.eval('.', editSession)

          runs ->
            selections = editSession.getSelections()
            expect(selections.length).toBe 3
            [selection1, selection2, selection3] = selections
            expect(selection1.getScreenRange()).toEqual preRange1
            expect(selection2.getScreenRange()).toEqual preRange2
            expect(selection3.getScreenRange()).toEqual preRange3

    describe "/regex/", ->
      beforeEach ->
        editSession.clearSelections()

      it 'selects text matching regex after current selection', ->
        waitsForPromise ->
          editSession.setSelectedBufferRange([[4,16], [4,20]])
          interpreter.eval('/pivot/', editSession)

        runs ->
          expect(editSession.getSelection().getBufferRange()).toEqual [[6,16], [6,21]]

      it 'does not require the trailing slash', ->
        waitsForPromise ->
          editSession.setSelectedBufferRange([[4,16], [4,20]])
          interpreter.eval('/pivot', editSession)

        runs ->
          expect(editSession.getSelection().getBufferRange()).toEqual [[6,16], [6,21]]

      it "searches from the end of each selection in the buffer", ->
        waitsForPromise ->
          editSession.clearSelections()
          editSession.setSelectedBufferRange([[4,16], [4,20]])
          editSession.addSelectionForBufferRange([[1,16], [2,20]])
          expect(editSession.getSelections().length).toBe 2
          interpreter.eval('/pivot', editSession)

        runs ->
          selections = editSession.getSelections()
          expect(selections.length).toBe 2
          expect(selections[0].getBufferRange()).toEqual [[3,8], [3,13]]
          expect(selections[1].getBufferRange()).toEqual [[6,16], [6,21]]

      it "wraps around to the beginning of the buffer, but doesn't infinitely loop if no matches are found", ->
        waitsForPromise ->
          editSession.setSelectedBufferRange([[10, 0], [10,3]])
          interpreter.eval('/pivot', editSession)

        runs ->
          expect(editSession.getSelection().getBufferRange()).toEqual [[3,8], [3,13]]

        waitsForPromise ->
          interpreter.eval('/mike tyson', editSession)

        runs ->
          expect(editSession.getSelection().getBufferRange()).toEqual [[3,8], [3,13]]

      it "searches in reverse when prefixed with a -", ->
        waitsForPromise ->
          editSession.setSelectedBufferRange([[6, 16], [6, 22]])
          interpreter.eval('-/pivot', editSession)

        runs ->
          expect(editSession.getSelection().getBufferRange()).toEqual [[3,8], [3,13]]

      it "removes folds that contain the selections", ->
        waitsForPromise ->
          editSession.createFold(5, 6)
          editSession.createFold(10, 11)
          editSession.setSelectedBufferRange([[4,16], [4,20]])
          interpreter.eval('/pivot/', editSession)

        runs ->
          expect(editSession.getSelection().getBufferRange()).toEqual [[6,16], [6,21]]
          expect(editSession.lineForScreenRow(5).fold).toBeUndefined()
          expect(editSession.lineForScreenRow(10).fold).toBeDefined()
          editSession.unfoldAll() # cleanup fold marker for after assertion

      it "is case-insentive when the pattern contains no non-escaped uppercase letters (behavior copied from vim)", ->
        waitsForPromise ->
          interpreter.eval('/array', editSession)
        runs ->
          expect(interpreter.lastRelativeAddress.subcommands[0].regex.toString()).toEqual "/array/i"

        waitsForPromise ->
          interpreter.eval('/a\\Sray', editSession)
        runs ->
          expect(interpreter.lastRelativeAddress.subcommands[0].regex.toString()).toEqual "/a\\Sray/i"

      it "allows the regex to contain an escaped forward slash", ->
        buffer.setText "hey/baby"

        waitsForPromise ->
          interpreter.eval('/y\\/b/', editSession)
        runs ->
          expect(editSession.getSelectedText()).toBe "y/b"

      it "does not push to the undo stack (since the buffer is not modified)", ->
        waitsForPromise ->
          editSession.setSelectedBufferRange([[4,16], [4,20]])
          interpreter.eval('/pivot/', editSession)

        runs ->
          selectedRangeBeforeUndo = editSession.getSelection().getBufferRange()
          editSession.undo()
          expect(editSession.getSelection().getBufferRange()).toEqual selectedRangeBeforeUndo

      describe "when no match is found", ->
        it "it returns an error messages", ->
          errorMessages = null
          waitsForPromise ->
            interpreter.eval('/garbage!', editSession).done (results) -> { errorMessages } = results

          runs ->
            expect(errorMessages.length).toBe 1

        waitsForPromise ->
          interpreter.eval('/Array', editSession)
        runs ->
          expect(interpreter.lastRelativeAddress.subcommands[0].regex.toString()).toEqual "/Array/"

      describe "when there is no active edit session", ->
        it "returns no error messages and does not throw an error", ->
          errorMessages = null

          waitsForPromise ->
            interpreter.eval('/something').done (results) ->
              {errorMessages} = results

          runs ->
            expect(errorMessages.length).toBe 0

    describe "address range", ->
      describe "when two addresses are specified", ->
        it "selects from the begining of the left address to the end of the right address", ->
          waitsForPromise -> interpreter.eval('4,7', editSession)

          runs ->
            expect(editSession.getSelections().length).toBe 1
            expect(editSession.getSelection().getBufferRange()).toEqual [[3, 0], [7, 0]]

      describe "when the left address is unspecified", ->
        it "selects from the begining of buffer to the end of the right address", ->
          waitsForPromise -> interpreter.eval(',7', editSession)
          runs ->
            expect(editSession.getSelections().length).toBe 1
            expect(editSession.getSelection().getBufferRange()).toEqual [[0, 0], [7, 0]]

      describe "when the right address is unspecified", ->
        it "selects from the begining of left address to the end file", ->
          waitsForPromise -> interpreter.eval('4,', editSession)
          runs ->
            expect(editSession.getSelections().length).toBe 1
            expect(editSession.getSelection().getBufferRange()).toEqual [[3, 0], [12, 2]]

      describe "when the neither address is specified", ->
        it "selects the entire file", ->
          waitsForPromise -> interpreter.eval(',', editSession)
          runs ->
            expect(editSession.getSelections().length).toBe 1
            expect(editSession.getSelection().getBufferRange()).toEqual [[0, 0], [12, 2]]

  describe "x/regex/", ->
    it "sets the current selection to every match of the regex in the current selection", ->
      waitsForPromise -> interpreter.eval('6,7 x/current/', editSession)

      runs ->
        selections = editSession.getSelections()
        expect(selections.length).toBe 4

        expect(selections[0].getBufferRange()).toEqual [[5,6], [5,13]]
        expect(selections[1].getBufferRange()).toEqual [[6,6], [6,13]]
        expect(selections[2].getBufferRange()).toEqual [[6,34], [6,41]]
        expect(selections[3].getBufferRange()).toEqual [[6,56], [6,63]]

    describe "when there is no address range is given", ->
      describe "when there is no text selection", ->
        it "uses the entire file as the address range", ->
          waitsForPromise ->
            editSession.clearSelections()
            interpreter.eval('x/return', editSession)
          runs ->
            expect(editSession.getSelectedBufferRanges()).toEqual [
              [[2,27],[2,33]]
              [[8,4], [8,10]]
              [[11,2],[11,8]]
            ]

      describe "when text is selected", ->
        it "uses the selection as the address range", ->
          waitsForPromise ->
            editSession.setSelectedBufferRange([[2, 0], [9, 0]])
            interpreter.eval('x/return', editSession)
          runs ->
            expect(editSession.getSelectedBufferRanges()).toEqual [
              [[2,27],[2,33]]
              [[8,4], [8,10]]
            ]

    describe "when matching /$/", ->
      it "matches the end of each line in the selected region", ->
        waitsForPromise -> interpreter.eval('6,8 x/$/', editSession)

        runs ->
          cursors = editSession.getCursors()
          expect(cursors.length).toBe 3

          expect(cursors[0].getBufferPosition()).toEqual [5, 30]
          expect(cursors[1].getBufferPosition()).toEqual [6, 65]
          expect(cursors[2].getBufferPosition()).toEqual [7, 5]

    describe "when text is initially selected", ->
      it "loops through current selections and selects text matching the regex", ->
        waitsForPromise ->
          editSession.setSelectedBufferRange [[3,0], [3,62]]
          editSession.addSelectionForBufferRange [[6,0], [6,65]]
          interpreter.eval('x/current', editSession)

        runs ->
          selections = editSession.getSelections()
          expect(selections.length).toBe 4

          expect(selections[0].getBufferRange()).toEqual [[3,31], [3,38]]
          expect(selections[1].getBufferRange()).toEqual [[6,6], [6,13]]
          expect(selections[2].getBufferRange()).toEqual [[6,34], [6,41]]
          expect(selections[3].getBufferRange()).toEqual [[6,56], [6,63]]

  describe "substitution", ->
    describe "when there is no address range is given", ->
      describe "when there is no text selection", ->
        it "uses the entire file as the address range", ->
          waitsForPromise ->
            editSession.clearSelections()
            interpreter.eval('s/current/foo/g', editSession)
          runs ->
            expect(buffer.lineForRow(3)).toBe '    var pivot = items.shift(), foo, left = [], right = [];'
            expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(foo) : right.push(foo);'

      describe "when text is selected", ->
        it "uses the selection as the address range", ->
          waitsForPromise ->
            editSession.setSelectedBufferRange([[6, 0], [6, 44]])
            interpreter.eval('s/current/foo/g', editSession)
          runs ->
            expect(buffer.lineForRow(3)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
            expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(foo) : right.push(current);'

    describe "when not global", ->
      describe "when there is a single selection", ->
        it "performs a single substitution within the current selection", ->
          waitsForPromise ->
            editSession.setSelectedBufferRange([[6, 0], [6, 44]])
            interpreter.eval('s/current/foo/', editSession)
          runs ->
            expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(current) : right.push(current);'

      describe "when there are multiple selections", ->
        it "performs a single substitutions within each of the selections", ->
          waitsForPromise ->
            editSession.setSelectedBufferRange([[5, 0], [5, 20]])
            editSession.addSelectionForBufferRange([[6, 0], [6, 44]])
            interpreter.eval('s/current/foo/', editSession)

          runs ->
            expect(buffer.lineForRow(5)).toBe '      foo = items.shift();'
            expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(current) : right.push(current);'

    describe "when global", ->
      it "performs a multiple substitutions within the current selection as a batch that can be undone in a single operation", ->
        waitsForPromise ->
          editSession.setSelectedBufferRange([[6, 0], [6, 44]])
          interpreter.eval('s/current/foo/g', editSession)

        runs ->
          expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(foo) : right.push(current);'
          buffer.undo()
          expect(buffer.getText()).not.toContain('foo')

      describe "when prefixed with an address", ->
        it "only makes substitutions within given lines", ->
          waitsForPromise -> interpreter.eval('4,6s/ /!/g', editSession)

          runs ->
            expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;'
            expect(buffer.lineForRow(3)).toBe '!!!!var!pivot!=!items.shift(),!current,!left!=![],!right!=![];'
            expect(buffer.lineForRow(4)).toBe '!!!!while(items.length!>!0)!{'
            expect(buffer.lineForRow(5)).toBe '!!!!!!current!=!items.shift();'
            expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(current) : right.push(current);'

      describe "when matching $", ->
        it "matches the end of each line and avoids infinitely looping on a zero-width match", ->
          waitsForPromise -> interpreter.eval(',s/$/!!!/g', editSession)
          runs ->
            expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {!!!'
            expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;!!!'
            expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(current) : right.push(current);!!!'
            expect(buffer.lineForRow(12)).toBe '};!!!'

      describe "when matching ^", ->
        it "matches the beginning of each line and avoids infinitely looping on a zero-width match", ->
          waitsForPromise -> interpreter.eval(',s/^/!!!/g', editSession)
          runs ->
            expect(buffer.lineForRow(0)).toBe '!!!var quicksort = function () {'
            expect(buffer.lineForRow(2)).toBe '!!!    if (items.length <= 1) return items;'
            expect(buffer.lineForRow(6)).toBe '!!!      current < pivot ? left.push(current) : right.push(current);'
            expect(buffer.lineForRow(12)).toBe '!!!};'

      describe "when there are multiple selections", ->
        it "performs a multiple substitutions within each of the selections", ->
          waitsForPromise ->
            editSession.setSelectedBufferRange([[5, 0], [5, 20]])
            editSession.addSelectionForBufferRange([[6, 0], [6, 44]])
            interpreter.eval('s/current/foo/g', editSession)

          runs ->
            expect(buffer.lineForRow(5)).toBe '      foo = items.shift();'
            expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(foo) : right.push(current);'

      describe "when prefixed with an address", ->
        it "restores the original selections upon completion if it is the last command", ->
          waitsForPromise ->
            editSession.setSelectedBufferRanges([[[5, 0], [5, 20]], [[6, 0], [6, 44]]])
            interpreter.eval(',s/current/foo/g', editSession)

          runs ->
            expect(editSession.getSelectedBufferRanges()).toEqual [[[5, 0], [5, 16]], [[6, 0], [6, 36]]]

    it "does nothing if there are no matches", ->
      waitsForPromise ->
        editSession.setSelectedBufferRange([[6, 0], [6, 44]])
        interpreter.eval('s/not-in-text/foo/', editSession)

      runs ->
        expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(current) : right.push(current);'

    it "properly handles escaped text in the replacement text", ->
      waitsForPromise ->
        interpreter.eval('s/  /\\t/g', editSession)
      runs ->
        expect(buffer.lineForRow(6)).toBe '\t\t\tcurrent < pivot ? left.push(current) : right.push(current);'

  describe "X x/regex/", ->
    it "returns selection operations for all regex matches in all the project's files", ->
      editSession.destroy()
      project.setPath(project.resolve('dir'))
      interpreter = new CommandInterpreter(project)

      operationsToPreview = null
      waitsForPromise ->
        interpreter.eval("X x/a+/").done (result) -> {operationsToPreview} = result

      runs ->
        expect(operationsToPreview.length).toBeGreaterThan 3
        for operation in operationsToPreview
          editSession = project.buildEditSession(operation.getPath())
          editSession.setSelectedBufferRange(operation.execute(editSession))
          expect(editSession.getSelectedText()).toMatch /a+/
          editSession.destroy()
          operation.destroy()

        editSession = null

  describe "nested commands", ->
    describe "/regex/ /regex", ->
      it "returns an error message if the last regex has no matches", ->
        previousSelections = null
        errorMessages = null
        waitsForPromise ->
          previousSelections = editSession.getSelectedBufferRanges()
          interpreter.eval('/sort/ /no match', editSession).done (results) -> { errorMessages } = results
        runs ->
          expect(errorMessages.length).toBe 1
