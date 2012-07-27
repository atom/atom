DisplayBuffer = require 'display-buffer'
Buffer = require 'buffer'

describe "DisplayBuffer", ->
  [editSession, displayBuffer, buffer, changeHandler, tabText] = []
  beforeEach ->
    tabText = '  '
    editSession = fixturesProject.buildEditSessionForPath('sample.js', { tabText })
    { buffer, displayBuffer } = editSession
    changeHandler = jasmine.createSpy 'changeHandler'
    displayBuffer.on 'change', changeHandler

  afterEach ->
    editSession.destroy()

  describe "when the buffer changes", ->
    it "renders line numbers correctly", ->
      originalLineCount = displayBuffer.lineCount()
      oneHundredLines = [0..100].join("\n")
      buffer.insert([0,0], oneHundredLines)
      expect(displayBuffer.lineCount()).toBe 100 + originalLineCount

  describe "soft wrapping", ->
    beforeEach ->
      displayBuffer.setSoftWrapColumn(50)
      changeHandler.reset()

    describe "rendering of soft-wrapped lines", ->
      describe "when the line is shorter than the max line length", ->
        it "renders the line unchanged", ->
          expect(displayBuffer.lineForRow(0).text).toBe buffer.lineForRow(0)

      describe "when the line is empty", ->
        it "renders the empty line", ->
          expect(displayBuffer.lineForRow(13).text).toBe ''

      describe "when there is a non-whitespace character at the max length boundary", ->
        describe "when there is whitespace before the boundary", ->
          it "wraps the line at the end of the first whitespace preceding the boundary", ->
            expect(displayBuffer.lineForRow(10).text).toBe '    return '
            expect(displayBuffer.lineForRow(11).text).toBe 'sort(left).concat(pivot).concat(sort(right));'

        describe "when there is no whitespace before the boundary", ->
          it "wraps the line exactly at the boundary since there's no more graceful place to wrap it", ->
            buffer.change([[0, 0], [1, 0]], 'abcdefghijklmnopqrstuvwxyz\n')
            displayBuffer.setSoftWrapColumn(10)
            expect(displayBuffer.lineForRow(0).text).toBe 'abcdefghij'
            expect(displayBuffer.lineForRow(1).text).toBe 'klmnopqrst'
            expect(displayBuffer.lineForRow(2).text).toBe 'uvwxyz'

      describe "when there is a whitespace character at the max length boundary", ->
        it "wraps the line at the first non-whitespace character following the boundary", ->
          expect(displayBuffer.lineForRow(3).text).toBe '    var pivot = items.shift(), current, left = [], '
          expect(displayBuffer.lineForRow(4).text).toBe 'right = [];'

    describe "when the buffer changes", ->
      describe "when buffer lines are updated", ->
        describe "when the update makes a soft-wrapped line shorter than the max line length", ->
          it "rewraps the line and emits a change event", ->
            buffer.delete([[6, 24], [6, 42]])
            expect(displayBuffer.lineForRow(7).text).toBe '      current < pivot ?  : right.push(current);'
            expect(displayBuffer.lineForRow(8).text).toBe '    }'

            expect(changeHandler).toHaveBeenCalled()
            [[event]]= changeHandler.argsForCall
            expect(event.oldRange).toEqual([[7, 0], [8, 20]])
            expect(event.newRange).toEqual([[7, 0], [7, 47]])
            expect(event.lineNumbersChanged).toBeTruthy()

        describe "when the update causes a line to softwrap an additional time", ->
          it "rewraps the line and emits a change event", ->
            buffer.insert([6, 28], '1234567890')
            expect(displayBuffer.lineForRow(7).text).toBe '      current < pivot ? '
            expect(displayBuffer.lineForRow(8).text).toBe 'left1234567890.push(current) : '
            expect(displayBuffer.lineForRow(9).text).toBe 'right.push(current);'
            expect(displayBuffer.lineForRow(10).text).toBe '    }'

            expect(changeHandler).toHaveBeenCalled()
            [[event]] = changeHandler.argsForCall
            expect(event.oldRange).toEqual([[7, 0], [8, 20]])
            expect(event.newRange).toEqual([[7, 0], [9, 20]])
            expect(event.lineNumbersChanged).toBeTruthy()

      describe "when buffer lines are inserted", ->
        it "inserts / updates wrapped lines and emits a change event", ->
          buffer.insert([6, 21], '1234567890 abcdefghij 1234567890\nabcdefghij')
          expect(displayBuffer.lineForRow(7).text).toBe '      current < pivot1234567890 abcdefghij '
          expect(displayBuffer.lineForRow(8).text).toBe '1234567890'
          expect(displayBuffer.lineForRow(9).text).toBe 'abcdefghij ? left.push(current) : '
          expect(displayBuffer.lineForRow(10).text).toBe 'right.push(current);'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[7, 0], [8, 20]])
          expect(event.newRange).toEqual([[7, 0], [10, 20]])
          expect(event.lineNumbersChanged).toBeTruthy()

      describe "when buffer lines are removed", ->
        it "removes lines and emits a change event", ->
          buffer.change([[3, 21], [7, 5]], ';')
          expect(displayBuffer.lineForRow(3).text).toBe '    var pivot = items;'
          expect(displayBuffer.lineForRow(4).text).toBe '    return '
          expect(displayBuffer.lineForRow(5).text).toBe 'sort(left).concat(pivot).concat(sort(right));'
          expect(displayBuffer.lineForRow(6).text).toBe '  };'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[3, 0], [11, 45]])
          expect(event.newRange).toEqual([[3, 0], [5, 45]])
          expect(event.lineNumbersChanged).toBeTruthy()

    describe "position translation", ->
      it "translates positions accounting for wrapped lines", ->
        # before any wrapped lines
        expect(displayBuffer.screenPositionForBufferPosition([0, 5])).toEqual([0, 5])
        expect(displayBuffer.bufferPositionForScreenPosition([0, 5])).toEqual([0, 5])
        expect(displayBuffer.screenPositionForBufferPosition([0, 29])).toEqual([0, 29])
        expect(displayBuffer.bufferPositionForScreenPosition([0, 29])).toEqual([0, 29])

        # on a wrapped line
        expect(displayBuffer.screenPositionForBufferPosition([3, 5])).toEqual([3, 5])
        expect(displayBuffer.bufferPositionForScreenPosition([3, 5])).toEqual([3, 5])
        expect(displayBuffer.screenPositionForBufferPosition([3, 50])).toEqual([3, 50])
        expect(displayBuffer.screenPositionForBufferPosition([3, 51])).toEqual([4, 0])
        expect(displayBuffer.bufferPositionForScreenPosition([4, 0])).toEqual([3, 51])
        expect(displayBuffer.bufferPositionForScreenPosition([3, 50])).toEqual([3, 50])
        expect(displayBuffer.screenPositionForBufferPosition([3, 62])).toEqual([4, 11])
        expect(displayBuffer.bufferPositionForScreenPosition([4, 11])).toEqual([3, 62])

        # following a wrapped line
        expect(displayBuffer.screenPositionForBufferPosition([4, 5])).toEqual([5, 5])
        expect(displayBuffer.bufferPositionForScreenPosition([5, 5])).toEqual([4, 5])

    describe ".setSoftWrapColumn(length)", ->
      it "changes the length at which lines are wrapped and emits a change event for all screen lines", ->
        displayBuffer.setSoftWrapColumn(40)
        expect(tokensText displayBuffer.lineForRow(4).tokens).toBe 'left = [], right = [];'
        expect(tokensText displayBuffer.lineForRow(5).tokens).toBe '    while(items.length > 0) {'
        expect(tokensText displayBuffer.lineForRow(12).tokens).toBe 'sort(left).concat(pivot).concat(sort(rig'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual([[0, 0], [15, 2]])
        expect(event.newRange).toEqual([[0, 0], [18, 2]])
        expect(event.lineNumbersChanged).toBeTruthy()

  describe "structural folding", ->
    describe "the foldable flag on screen lines", ->
      it "sets 'foldable' to true for screen lines that start a foldable region", ->
        expect(displayBuffer.lineForRow(0).foldable).toBeTruthy()
        expect(displayBuffer.lineForRow(1).foldable).toBeTruthy()
        expect(displayBuffer.lineForRow(2).foldable).toBeFalsy()
        expect(displayBuffer.lineForRow(3).foldable).toBeFalsy()

      describe "when a foldable line is wrapped", ->
        it "only marks the first screen line as foldable", ->
          displayBuffer.setSoftWrapColumn(20)
          expect(displayBuffer.lineForRow(0).foldable).toBeTruthy()
          expect(displayBuffer.lineForRow(1).foldable).toBeFalsy()
          expect(displayBuffer.lineForRow(2).foldable).toBeTruthy()
          expect(displayBuffer.lineForRow(3).foldable).toBeFalsy()

    describe ".foldAll()", ->
      it "folds every foldable line", ->
        displayBuffer.foldAll()
        fold = displayBuffer.lineForRow(0).fold
        expect(fold).toBeDefined()
        expect([fold.startRow, fold.endRow]).toEqual [0,12]

        expect(Object.keys(displayBuffer.activeFolds).length).toBe(3)
        expect(displayBuffer.activeFolds[1].length).toBe(1)
        expect(displayBuffer.activeFolds[4].length).toBe(1)

      it "doesn't fold lines that are already folded", ->
        displayBuffer.toggleFoldAtBufferRow(4)
        displayBuffer.foldAll()
        expect(Object.keys(displayBuffer.activeFolds).length).toBe(3)
        expect(displayBuffer.activeFolds[0].length).toBe(1)
        expect(displayBuffer.activeFolds[1].length).toBe(1)
        expect(displayBuffer.activeFolds[4].length).toBe(1)

    describe ".toggleFoldAtBufferRow(bufferRow)", ->
      describe "when bufferRow can be folded", ->
        it "creates/destroys a fold based on the syntactic region starting at the given row", ->
          displayBuffer.toggleFoldAtBufferRow(1)
          fold = displayBuffer.lineForRow(1).fold
          expect(fold.startRow).toBe 1
          expect(fold.endRow).toBe 9

          displayBuffer.toggleFoldAtBufferRow(1)
          expect(displayBuffer.lineForRow(1).fold).toBeUndefined()

      describe "when bufferRow can't be folded", ->
        it "searches upward for the first row that begins a syntatic region containing the given buffer row (and folds it)", ->
          displayBuffer.toggleFoldAtBufferRow(8)
          fold = displayBuffer.lineForRow(1).fold
          expect(fold.startRow).toBe 1
          expect(fold.endRow).toBe 9

  describe "primitive folding", ->
    editSession2 = null

    beforeEach ->
      editSession2 = fixturesProject.buildEditSessionForPath('two-hundred.txt')
      { buffer, displayBuffer } = editSession2
      displayBuffer.on 'change', changeHandler

    afterEach ->
      editSession2.destroy()

    describe "when folds are created and destroyed", ->
      describe "when a fold spans multiple lines", ->
        it "replaces the lines spanned by the fold with a placeholder that references the fold object", ->
          fold = displayBuffer.createFold(4, 7)

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBe fold
          expect(line4.text).toMatch /^4-+/
          expect(line4.bufferDelta).toEqual [4, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toBe '8'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual [[4, 0], [7, 1]]
          expect(event.newRange).toEqual [[4, 0], [4, 101]]
          expect(event.lineNumbersChanged).toBeTruthy()
          changeHandler.reset()

          fold.destroy()
          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBeUndefined()
          expect(line4.text).toMatch /^4-+/
          expect(line4.bufferDelta).toEqual [1, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toBe '5'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 101]]
          expect(event.newRange).toEqual [[4, 0], [7, 1]]
          expect(event.lineNumbersChanged).toBeTruthy()

      describe "when a fold spans a single line", ->
        it "renders a fold placeholder for the folded line but does not skip any lines", ->
          fold = displayBuffer.createFold(4, 4)

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBe fold
          expect(line4.text).toMatch /^4-+/
          expect(line4.bufferDelta).toEqual [1, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toBe '5'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 101]]
          expect(event.newRange).toEqual [[4, 0], [4, 101]]

          # Line numbers don't actually change, but it's not worth the complexity to have this
          # be false for single line folds since they are so rare
          expect(event.lineNumbersChanged).toBeTruthy()
          changeHandler.reset()

          fold.destroy()

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBeUndefined()
          expect(line4.text).toMatch /^4-+/
          expect(line4.bufferDelta).toEqual [1, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toBe '5'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 101]]
          expect(event.newRange).toEqual [[4, 0], [4, 101]]
          expect(event.lineNumbersChanged).toBeTruthy()
          changeHandler.reset()

      describe "when a fold is nested within another fold", ->
        it "does not render the placeholder for the inner fold until the outer fold is destroyed", ->
          innerFold = displayBuffer.createFold(6, 7)
          outerFold = displayBuffer.createFold(4, 8)

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBe outerFold
          expect(line4.text).toMatch /4-+/
          expect(line4.bufferDelta).toEqual [5, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toMatch /9-+/

          outerFold.destroy()

          [line4, line5, line6, line7] = displayBuffer.linesForRows(4, 7)
          expect(line4.fold).toBeUndefined()
          expect(line4.text).toMatch /^4-+/
          expect(line4.bufferDelta).toEqual [1, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toBe '5'
          expect(line6.fold).toBe innerFold
          expect(line6.text).toBe '6'
          expect(line6.bufferDelta).toEqual [2, 0]
          expect(line6.screenDelta).toEqual [1, 0]
          expect(line7.text).toBe '8'

        it "allows the outer fold to start at the same location as the inner fold", ->
          innerFold = displayBuffer.createFold(4, 6)
          outerFold = displayBuffer.createFold(4, 8)

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBe outerFold
          expect(line4.text).toMatch /4-+/
          expect(line4.bufferDelta).toEqual [5, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toMatch /9-+/

      describe "when creating a fold where one already exists", ->
        it "returns existing fold and does't create new fold", ->
          fold = displayBuffer.createFold(0,10)
          expect(displayBuffer.activeFolds[0].length).toBe 1

          newFold = displayBuffer.createFold(0,10)
          expect(newFold).toBe fold
          expect(displayBuffer.activeFolds[0].length).toBe 1

      describe "when a fold is created inside an existing folded region", ->
        it "creates/destroys the fold, but does not trigger change event", ->
          outerFold = displayBuffer.createFold(0, 10)
          changeHandler.reset()

          innerFold = displayBuffer.createFold(2, 5)
          expect(changeHandler).not.toHaveBeenCalled()
          [line0, line1] = displayBuffer.linesForRows(0, 1)
          expect(line0.fold).toBe outerFold
          expect(line1.fold).toBeUndefined()

          changeHandler.reset()
          innerFold.destroy()
          expect(changeHandler).not.toHaveBeenCalled()
          [line0, line1] = displayBuffer.linesForRows(0, 1)
          expect(line0.fold).toBe outerFold
          expect(line1.fold).toBeUndefined()

    describe "when the buffer changes", ->
      [fold1, fold2] = []
      beforeEach ->
        fold1 = displayBuffer.createFold(2, 4)
        fold2 = displayBuffer.createFold(6, 8)
        changeHandler.reset()

      describe "when the old range surrounds a fold", ->
        it "removes the fold and replaces the selection with the new text", ->
          buffer.change([[1, 0], [5, 1]], 'party!')

          expect(displayBuffer.lineForRow(0).text).toBe "0"
          expect(displayBuffer.lineForRow(1).text).toBe "party!"
          expect(displayBuffer.lineForRow(2).fold).toBe fold2
          expect(displayBuffer.lineForRow(3).text).toMatch /^9-+/

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[1, 0], [3, 1]]
          expect(event.newRange).toEqual [[1, 0], [1, 6]]
          expect(event.lineNumbersChanged).toBeTruthy()

      describe "when the old range surrounds two nested folds", ->
        it "removes both folds and replaces the selection with the new text", ->
          displayBuffer.createFold(2, 9)
          changeHandler.reset()

          buffer.change([[1, 0], [10, 0]], 'goodbye')

          expect(displayBuffer.lineForRow(0).text).toBe "0"
          expect(displayBuffer.lineForRow(1).text).toBe "goodbye10"
          expect(displayBuffer.lineForRow(2).text).toBe "11"

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[1, 0], [3, 2]]
          expect(event.newRange).toEqual [[1, 0], [1, 9]]
          expect(event.lineNumbersChanged).toBeTruthy()

      describe "when multiple changes happen above the fold", ->
        it "repositions folds correctly", ->
          buffer.delete([[1, 1], [2, 0]])
          buffer.insert([0, 1], "\nnew")

          expect(fold1.startRow).toBe 2
          expect(fold1.endRow).toBe 4

      describe "when the old range precedes lines with a fold", ->
        describe "when the new range precedes lines with a fold", ->
          it "updates the buffer and re-positions subsequent folds", ->
            buffer.change([[0, 0], [1, 1]], 'abc')

            expect(displayBuffer.lineForRow(0).text).toBe "abc"
            expect(displayBuffer.lineForRow(1).fold).toBe fold1
            expect(displayBuffer.lineForRow(2).text).toBe "5"
            expect(displayBuffer.lineForRow(3).fold).toBe fold2
            expect(displayBuffer.lineForRow(4).text).toMatch /^9-+/

            expect(changeHandler).toHaveBeenCalled()
            [[event]] = changeHandler.argsForCall
            expect(event.oldRange).toEqual [[0, 0], [1, 1]]
            expect(event.newRange).toEqual [[0, 0], [0, 3]]
            expect(event.lineNumbersChanged).toBeTruthy()
            changeHandler.reset()

            fold1.destroy()
            expect(displayBuffer.lineForRow(0).text).toBe "abc"
            expect(displayBuffer.lineForRow(1).text).toBe "2"
            expect(displayBuffer.lineForRow(3).text).toMatch /^4-+/
            expect(displayBuffer.lineForRow(4).text).toBe "5"
            expect(displayBuffer.lineForRow(5).fold).toBe fold2
            expect(displayBuffer.lineForRow(6).text).toMatch /^9-+/

            expect(changeHandler).toHaveBeenCalled()
            [[event]] = changeHandler.argsForCall
            expect(event.oldRange).toEqual [[1, 0], [1, 1]]
            expect(event.newRange).toEqual [[1, 0], [3, 101]]
            expect(event.lineNumbersChanged).toBeTruthy()

      describe "when the old range straddles the beginning of a fold", ->
        it "replaces lines in the portion of the range that precedes the fold and adjusts the end of the fold to encompass additional lines", ->
          buffer.change([[1, 1], [3, 0]], "a\nb\nc\nd\n")

          expect(fold1.startRow).toBe 2
          expect(fold1.endRow).toBe 6

          expect(displayBuffer.lineForRow(1).text).toBe '1a'
          expect(displayBuffer.lineForRow(2).text).toBe 'b'
          expect(displayBuffer.lineForRow(2).fold).toBe fold1

      describe "when the old range follows a fold", ->
        it "re-positions the screen ranges for the change event based on the preceding fold", ->
          buffer.change([[10, 0], [11, 0]], 'abc')

          expect(displayBuffer.lineForRow(1).text).toBe "1"
          expect(displayBuffer.lineForRow(2).fold).toBe fold1
          expect(displayBuffer.lineForRow(3).text).toBe "5"
          expect(displayBuffer.lineForRow(4).fold).toBe fold2
          expect(displayBuffer.lineForRow(5).text).toMatch /^9-+/

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[6, 0], [7, 2]] # Expands ranges to encompes entire line
          expect(event.newRange).toEqual [[6, 0], [6, 5]]
          expect(event.lineNumbersChanged).toBeTruthy()

      describe "when the old range is inside a fold", ->
        describe "when the end of the new range precedes the end of the fold", ->
          it "updates the fold and ensures the change is present when the fold is destroyed", ->
            buffer.insert([3, 0], '\n')
            expect(fold1.startRow).toBe 2
            expect(fold1.endRow).toBe 5

            expect(displayBuffer.lineForRow(1).text).toBe "1"
            expect(displayBuffer.lineForRow(2).text).toBe "2"
            expect(displayBuffer.lineForRow(2).fold).toBe fold1
            expect(displayBuffer.lineForRow(2).bufferDelta).toEqual [4, 0]
            expect(displayBuffer.lineForRow(3).text).toMatch "5"
            expect(displayBuffer.lineForRow(4).fold).toBe fold2
            expect(displayBuffer.lineForRow(5).text).toMatch /^9-+/

            expect(changeHandler).toHaveBeenCalled()
            [[event]] = changeHandler.argsForCall
            expect(event.oldRange).toEqual [[2, 0], [2, 1]]
            expect(event.newRange).toEqual [[2, 0], [2, 1]]
            expect(event.lineNumbersChanged).toBeTruthy()

        describe "when the end of the new range exceeds the end of the fold", ->
          it "expands the fold to contain all the inserted lines", ->
            buffer.change([[3, 0], [4, 0]], 'a\nb\nc\nd\n')
            expect(fold1.startRow).toBe 2
            expect(fold1.endRow).toBe 7

            expect(displayBuffer.lineForRow(1).text).toBe "1"
            expect(displayBuffer.lineForRow(2).text).toBe "2"
            expect(displayBuffer.lineForRow(2).fold).toBe fold1
            expect(displayBuffer.lineForRow(2).bufferDelta).toEqual [6, 0]
            expect(displayBuffer.lineForRow(3).text).toMatch "5"
            expect(displayBuffer.lineForRow(4).fold).toBe fold2
            expect(displayBuffer.lineForRow(5).text).toMatch /^9-+/

            expect(changeHandler).toHaveBeenCalled()
            [[event]] = changeHandler.argsForCall
            expect(event.oldRange).toEqual [[2, 0], [2, 1]]
            expect(event.newRange).toEqual [[2, 0], [2, 1]]
            expect(event.lineNumbersChanged).toBeTruthy()

      describe "when the old range straddles the end of the fold", ->
        describe "when the end of the new range precedes the end of the fold", ->
          it "shortens the fold so its end matches the end of the new range", ->
            fold2.destroy()
            buffer.change([[3, 0], [6, 0]], 'a\n')

            expect(fold1.startRow).toBe 2
            expect(fold1.endRow).toBe 4

      describe "when the old range is contained to a single line in-between two folds", ->
        it "re-renders the line with the placeholder and re-positions the second fold", ->
          buffer.insert([5, 0], 'abc\n')

          expect(displayBuffer.lineForRow(1).text).toBe "1"
          expect(displayBuffer.lineForRow(2).fold).toBe fold1
          expect(displayBuffer.lineForRow(3).text).toMatch "abc"
          expect(displayBuffer.lineForRow(4).text).toBe "5"
          expect(displayBuffer.lineForRow(5).fold).toBe fold2
          expect(displayBuffer.lineForRow(6).text).toMatch /^9-+/

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[3, 0], [3, 1]]
          expect(event.newRange).toEqual [[3, 0], [4, 1]]
          expect(event.lineNumbersChanged).toBeTruthy()

    describe "position translation", ->
      it "translates positions to account for folded lines and characters and the placeholder", ->
        displayBuffer.createFold(4, 7)

        # preceding fold: identity
        expect(displayBuffer.screenPositionForBufferPosition([3, 0])).toEqual [3, 0]
        expect(displayBuffer.screenPositionForBufferPosition([4, 0])).toEqual [4, 0]

        expect(displayBuffer.bufferPositionForScreenPosition([3, 0])).toEqual [3, 0]
        expect(displayBuffer.bufferPositionForScreenPosition([4, 0])).toEqual [4, 0]

        # inside of fold: translate to the start of the fold
        expect(displayBuffer.screenPositionForBufferPosition([4, 35])).toEqual [4, 0]
        expect(displayBuffer.screenPositionForBufferPosition([5, 5])).toEqual [4, 0]

        # following fold
        expect(displayBuffer.screenPositionForBufferPosition([8, 0])).toEqual [5, 0]
        expect(displayBuffer.screenPositionForBufferPosition([11, 2])).toEqual [8, 2]

        expect(displayBuffer.bufferPositionForScreenPosition([5, 0])).toEqual [8, 0]
        expect(displayBuffer.bufferPositionForScreenPosition([9, 2])).toEqual [12, 2]

    describe ".destroyFoldsContainingBufferRow(row)", ->
      it "destroys all folds containing the given row", ->
          displayBuffer.createFold(2, 4)
          displayBuffer.createFold(2, 6)
          displayBuffer.createFold(7, 8)
          displayBuffer.createFold(1, 9)
          displayBuffer.createFold(11, 12)

          expect(displayBuffer.lineForRow(1).text).toBe '1'
          expect(displayBuffer.lineForRow(2).text).toBe '10'

          displayBuffer.destroyFoldsContainingBufferRow(2)
          expect(displayBuffer.lineForRow(1).text).toBe '1'
          expect(displayBuffer.lineForRow(2).text).toBe '2'
          expect(displayBuffer.lineForRow(7).fold).toBeDefined()
          expect(displayBuffer.lineForRow(8).text).toMatch /^9-+/
          expect(displayBuffer.lineForRow(10).fold).toBeDefined()

  describe ".clipScreenPosition(screenPosition, wrapBeyondNewlines: false, wrapAtSoftNewlines: false, skipAtomicTokens: false)", ->
    beforeEach ->
      displayBuffer.setSoftWrapColumn(50)

    it "allows valid positions", ->
      expect(displayBuffer.clipScreenPosition([4, 5])).toEqual [4, 5]
      expect(displayBuffer.clipScreenPosition([4, 11])).toEqual [4, 11]

    it "disallows negative positions", ->
      expect(displayBuffer.clipScreenPosition([-1, -1])).toEqual [0, 0]
      expect(displayBuffer.clipScreenPosition([-1, 10])).toEqual [0, 0]
      expect(displayBuffer.clipScreenPosition([0, -1])).toEqual [0, 0]

    it "disallows positions beyond the last row", ->
      expect(displayBuffer.clipScreenPosition([1000, 0])).toEqual [15, 2]
      expect(displayBuffer.clipScreenPosition([1000, 1000])).toEqual [15, 2]

    describe "when wrapBeyondNewlines is false (the default)", ->
      it "wraps positions beyond the end of hard newlines to the end of the line", ->
        expect(displayBuffer.clipScreenPosition([1, 10000])).toEqual [1, 30]
        expect(displayBuffer.clipScreenPosition([4, 30])).toEqual [4, 11]
        expect(displayBuffer.clipScreenPosition([4, 1000])).toEqual [4, 11]

    describe "when wrapBeyondNewlines is true", ->
      it "wraps positions past the end of hard newlines to the next line", ->
        expect(displayBuffer.clipScreenPosition([0, 29], wrapBeyondNewlines: true)).toEqual [0, 29]
        expect(displayBuffer.clipScreenPosition([0, 30], wrapBeyondNewlines: true)).toEqual [1, 0]
        expect(displayBuffer.clipScreenPosition([0, 1000], wrapBeyondNewlines: true)).toEqual [1, 0]

      it "wraps positions in the middle of fold lines to the next screen line", ->
        displayBuffer.createFold(3, 5)
        expect(displayBuffer.clipScreenPosition([3, 5], wrapBeyondNewlines: true)).toEqual [4, 0]

    describe "when wrapAtSoftNewlines is false (the default)", ->
      it "clips positions at the end of soft-wrapped lines to the character preceding the end of the line", ->
        expect(displayBuffer.clipScreenPosition([3, 50])).toEqual [3, 50]
        expect(displayBuffer.clipScreenPosition([3, 51])).toEqual [3, 50]
        expect(displayBuffer.clipScreenPosition([3, 58])).toEqual [3, 50]
        expect(displayBuffer.clipScreenPosition([3, 1000])).toEqual [3, 50]

    describe "when wrapAtSoftNewlines is true", ->
      it "wraps positions at the end of soft-wrapped lines to the next screen line", ->
        expect(displayBuffer.clipScreenPosition([3, 50], wrapAtSoftNewlines: true)).toEqual [3, 50]
        expect(displayBuffer.clipScreenPosition([3, 51], wrapAtSoftNewlines: true)).toEqual [4, 0]
        expect(displayBuffer.clipScreenPosition([3, 58], wrapAtSoftNewlines: true)).toEqual [4, 0]
        expect(displayBuffer.clipScreenPosition([3, 1000], wrapAtSoftNewlines: true)).toEqual [4, 0]

    describe "when skipAtomicTokens is false (the default)", ->
      it "clips screen positions in the middle of atomic tab characters to the beginning of the character", ->
        buffer.insert([0, 0], '\t')
        expect(displayBuffer.clipScreenPosition([0, 0])).toEqual [0, 0]
        expect(displayBuffer.clipScreenPosition([0, 1])).toEqual [0, 0]
        expect(displayBuffer.clipScreenPosition([0, tabText.length])).toEqual [0, tabText.length]

    describe "when skipAtomicTokens is true", ->
      it "clips screen positions in the middle of atomic tab characters to the end of the character", ->
        buffer.insert([0, 0], '\t')
        expect(displayBuffer.clipScreenPosition([0, 0], skipAtomicTokens: true)).toEqual [0, 0]
        expect(displayBuffer.clipScreenPosition([0, 1], skipAtomicTokens: true)).toEqual [0, tabText.length]
        expect(displayBuffer.clipScreenPosition([0, tabText.length], skipAtomicTokens: true)).toEqual [0, tabText.length]

  describe ".maxLineLength()", ->
    it "returns the length of the longest screen line", ->
      expect(displayBuffer.maxLineLength()).toBe 65

