DisplayBuffer = require 'display-buffer'
Buffer = require 'text-buffer'
_ = require 'underscore'

describe "DisplayBuffer", ->
  [displayBuffer, buffer, changeHandler, tabLength] = []
  beforeEach ->
    tabLength = 2
    atom.activatePackage('javascript.tmbundle', sync: true)
    buffer = project.bufferForPath('sample.js')
    displayBuffer = new DisplayBuffer(buffer, { tabLength })
    displayBuffer.on 'changed', changeHandler = jasmine.createSpy 'changeHandler'

  afterEach ->
    displayBuffer.destroy()
    buffer.release()

  describe "when the buffer changes", ->
    it "renders line numbers correctly", ->
      originalLineCount = displayBuffer.getLineCount()
      oneHundredLines = [0..100].join("\n")
      buffer.insert([0,0], oneHundredLines)
      expect(displayBuffer.getLineCount()).toBe 100 + originalLineCount

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
        describe "when whitespace is added after the max line length", ->
          it "adds whitespace to the end of the current line and wraps an empty line", ->
            fiftyCharacters = _.multiplyString("x", 50)
            buffer.setText(fiftyCharacters)
            buffer.insert([0, 51], " ")

        describe "when the update makes a soft-wrapped line shorter than the max line length", ->
          it "rewraps the line and emits a change event", ->
            buffer.delete([[6, 24], [6, 42]])
            expect(displayBuffer.lineForRow(7).text).toBe '      current < pivot ?  : right.push(current);'
            expect(displayBuffer.lineForRow(8).text).toBe '    }'

            expect(changeHandler).toHaveBeenCalled()
            [[event]]= changeHandler.argsForCall

            expect(event).toEqual(start: 7, end: 8, screenDelta: -1, bufferDelta: 0)

        describe "when the update causes a line to softwrap an additional time", ->
          it "rewraps the line and emits a change event", ->
            buffer.insert([6, 28], '1234567890')
            expect(displayBuffer.lineForRow(7).text).toBe '      current < pivot ? '
            expect(displayBuffer.lineForRow(8).text).toBe 'left1234567890.push(current) : '
            expect(displayBuffer.lineForRow(9).text).toBe 'right.push(current);'
            expect(displayBuffer.lineForRow(10).text).toBe '    }'

            expect(changeHandler).toHaveBeenCalledWith(start: 7, end: 8, screenDelta: 1, bufferDelta: 0)

      describe "when buffer lines are inserted", ->
        it "inserts / updates wrapped lines and emits a change event", ->
          buffer.insert([6, 21], '1234567890 abcdefghij 1234567890\nabcdefghij')
          expect(displayBuffer.lineForRow(7).text).toBe '      current < pivot1234567890 abcdefghij '
          expect(displayBuffer.lineForRow(8).text).toBe '1234567890'
          expect(displayBuffer.lineForRow(9).text).toBe 'abcdefghij ? left.push(current) : '
          expect(displayBuffer.lineForRow(10).text).toBe 'right.push(current);'

          expect(changeHandler).toHaveBeenCalledWith(start: 7, end: 8, screenDelta: 2, bufferDelta: 1)

      describe "when buffer lines are removed", ->
        it "removes lines and emits a change event", ->
          buffer.change([[3, 21], [7, 5]], ';')
          expect(displayBuffer.lineForRow(3).text).toBe '    var pivot = items;'
          expect(displayBuffer.lineForRow(4).text).toBe '    return '
          expect(displayBuffer.lineForRow(5).text).toBe 'sort(left).concat(pivot).concat(sort(right));'
          expect(displayBuffer.lineForRow(6).text).toBe '  };'

          expect(changeHandler).toHaveBeenCalledWith(start: 3, end: 9, screenDelta: -6, bufferDelta: -4)

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
        expect(displayBuffer.screenPositionForBufferPosition([3, 51])).toEqual([3, 50])
        expect(displayBuffer.bufferPositionForScreenPosition([4, 0])).toEqual([3, 51])
        expect(displayBuffer.bufferPositionForScreenPosition([3, 50])).toEqual([3, 50])
        expect(displayBuffer.screenPositionForBufferPosition([3, 62])).toEqual([4, 11])
        expect(displayBuffer.bufferPositionForScreenPosition([4, 11])).toEqual([3, 62])

        # following a wrapped line
        expect(displayBuffer.screenPositionForBufferPosition([4, 5])).toEqual([5, 5])
        expect(displayBuffer.bufferPositionForScreenPosition([5, 5])).toEqual([4, 5])

        # clip screen position inputs before translating
        expect(displayBuffer.bufferPositionForScreenPosition([-5, -5])).toEqual([0, 0])
        expect(displayBuffer.bufferPositionForScreenPosition([Infinity, Infinity])).toEqual([12, 2])
        expect(displayBuffer.bufferPositionForScreenPosition([3, -5])).toEqual([3, 0])
        expect(displayBuffer.bufferPositionForScreenPosition([3, Infinity])).toEqual([3, 50])

    describe ".setSoftWrapColumn(length)", ->
      it "changes the length at which lines are wrapped and emits a change event for all screen lines", ->
        displayBuffer.setSoftWrapColumn(40)
        expect(tokensText displayBuffer.lineForRow(4).tokens).toBe 'left = [], right = [];'
        expect(tokensText displayBuffer.lineForRow(5).tokens).toBe '    while(items.length > 0) {'
        expect(tokensText displayBuffer.lineForRow(12).tokens).toBe 'sort(left).concat(pivot).concat(sort(rig'
        expect(changeHandler).toHaveBeenCalledWith(start: 0, end: 15, screenDelta: 3, bufferDelta: 0)

  describe "primitive folding", ->
    beforeEach ->
      displayBuffer.destroy()
      buffer.release()
      buffer = project.bufferForPath('two-hundred.txt')
      displayBuffer = new DisplayBuffer(buffer, { tabLength })
      displayBuffer.on 'changed', changeHandler

    describe "when folds are created and destroyed", ->
      describe "when a fold spans multiple lines", ->
        it "replaces the lines spanned by the fold with a placeholder that references the fold object", ->
          fold = displayBuffer.createFold(4, 7)

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBe fold
          expect(line4.text).toMatch /^4-+/
          expect(line5.text).toBe '8'

          expect(changeHandler).toHaveBeenCalledWith(start: 4, end: 7, screenDelta: -3, bufferDelta: 0)
          changeHandler.reset()

          fold.destroy()
          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBeUndefined()
          expect(line4.text).toMatch /^4-+/
          expect(line5.text).toBe '5'

          expect(changeHandler).toHaveBeenCalledWith(start: 4, end: 4, screenDelta: 3, bufferDelta: 0)

      describe "when a fold spans a single line", ->
        it "renders a fold placeholder for the folded line but does not skip any lines", ->
          fold = displayBuffer.createFold(4, 4)

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBe fold
          expect(line4.text).toMatch /^4-+/
          expect(line5.text).toBe '5'

          expect(changeHandler).toHaveBeenCalledWith(start: 4, end: 4, screenDelta: 0, bufferDelta: 0)

          # Line numbers don't actually change, but it's not worth the complexity to have this
          # be false for single line folds since they are so rare
          changeHandler.reset()

          fold.destroy()

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBeUndefined()
          expect(line4.text).toMatch /^4-+/
          expect(line5.text).toBe '5'

          expect(changeHandler).toHaveBeenCalledWith(start: 4, end: 4, screenDelta: 0, bufferDelta: 0)

      describe "when a fold is nested within another fold", ->
        it "does not render the placeholder for the inner fold until the outer fold is destroyed", ->
          innerFold = displayBuffer.createFold(6, 7)
          outerFold = displayBuffer.createFold(4, 8)

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBe outerFold
          expect(line4.text).toMatch /4-+/
          expect(line5.text).toMatch /9-+/

          outerFold.destroy()
          [line4, line5, line6, line7] = displayBuffer.linesForRows(4, 7)
          expect(line4.fold).toBeUndefined()
          expect(line4.text).toMatch /^4-+/
          expect(line5.text).toBe '5'
          expect(line6.fold).toBe innerFold
          expect(line6.text).toBe '6'
          expect(line7.text).toBe '8'

        it "allows the outer fold to start at the same location as the inner fold", ->
          innerFold = displayBuffer.createFold(4, 6)
          outerFold = displayBuffer.createFold(4, 8)

          [line4, line5] = displayBuffer.linesForRows(4, 5)
          expect(line4.fold).toBe outerFold
          expect(line4.text).toMatch /4-+/
          expect(line5.text).toMatch /9-+/

      describe "when creating a fold where one already exists", ->
        it "returns existing fold and does't create new fold", ->
          fold = displayBuffer.createFold(0,10)
          expect(displayBuffer.findMarkers(class: 'fold').length).toBe 1

          newFold = displayBuffer.createFold(0,10)
          expect(newFold).toBe fold
          expect(displayBuffer.findMarkers(class: 'fold').length).toBe 1

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

      describe "when there is another display buffer pointing to the same buffer", ->
        it "does not create folds in the other display buffer", ->
          otherDisplayBuffer = new DisplayBuffer(buffer, { tabLength })
          displayBuffer.createFold(2, 4)
          expect(otherDisplayBuffer.foldsStartingAtBufferRow(2).length).toBe 0

    describe "when the buffer changes", ->
      [fold1, fold2] = []
      beforeEach ->
        fold1 = displayBuffer.createFold(2, 4)
        fold2 = displayBuffer.createFold(6, 8)
        changeHandler.reset()

      describe "when the old range surrounds a fold", ->
        beforeEach ->
          buffer.change([[1, 0], [5, 1]], 'party!')

        it "removes the fold and replaces the selection with the new text", ->
          expect(displayBuffer.lineForRow(0).text).toBe "0"
          expect(displayBuffer.lineForRow(1).text).toBe "party!"
          expect(displayBuffer.lineForRow(2).fold).toBe fold2
          expect(displayBuffer.lineForRow(3).text).toMatch /^9-+/

          expect(changeHandler).toHaveBeenCalledWith(start: 1, end: 3, screenDelta: -2, bufferDelta: -4)

        describe "when the changes is subsequently undone", ->
          it "restores destroyed folds", ->
            buffer.undo()
            expect(displayBuffer.lineForRow(2).text).toBe '2'
            expect(displayBuffer.lineForRow(2).fold).toBe fold1
            expect(displayBuffer.lineForRow(3).text).toBe '5'

      describe "when the old range surrounds two nested folds", ->
        it "removes both folds and replaces the selection with the new text", ->
          displayBuffer.createFold(2, 9)
          changeHandler.reset()

          buffer.change([[1, 0], [10, 0]], 'goodbye')

          expect(displayBuffer.lineForRow(0).text).toBe "0"
          expect(displayBuffer.lineForRow(1).text).toBe "goodbye10"
          expect(displayBuffer.lineForRow(2).text).toBe "11"

          expect(changeHandler).toHaveBeenCalledWith(start: 1, end: 3, screenDelta: -2, bufferDelta: -9)

      describe "when multiple changes happen above the fold", ->
        it "repositions folds correctly", ->
          buffer.delete([[1, 1], [2, 0]])
          buffer.insert([0, 1], "\nnew")

          expect(fold1.getStartRow()).toBe 2
          expect(fold1.getEndRow()).toBe 4

      describe "when the old range precedes lines with a fold", ->
        describe "when the new range precedes lines with a fold", ->
          it "updates the buffer and re-positions subsequent folds", ->
            buffer.change([[0, 0], [1, 1]], 'abc')

            expect(displayBuffer.lineForRow(0).text).toBe "abc"
            expect(displayBuffer.lineForRow(1).fold).toBe fold1
            expect(displayBuffer.lineForRow(2).text).toBe "5"
            expect(displayBuffer.lineForRow(3).fold).toBe fold2
            expect(displayBuffer.lineForRow(4).text).toMatch /^9-+/

            expect(changeHandler).toHaveBeenCalledWith(start: 0, end: 1, screenDelta: -1, bufferDelta: -1)
            changeHandler.reset()

            fold1.destroy()
            expect(displayBuffer.lineForRow(0).text).toBe "abc"
            expect(displayBuffer.lineForRow(1).text).toBe "2"
            expect(displayBuffer.lineForRow(3).text).toMatch /^4-+/
            expect(displayBuffer.lineForRow(4).text).toBe "5"
            expect(displayBuffer.lineForRow(5).fold).toBe fold2
            expect(displayBuffer.lineForRow(6).text).toMatch /^9-+/

            expect(changeHandler).toHaveBeenCalledWith(start: 1, end: 1, screenDelta: 2, bufferDelta: 0)

      describe "when the old range straddles the beginning of a fold", ->
        it "destroys the fold", ->
          buffer.change([[1, 1], [3, 0]], "a\nb\nc\nd\n")
          expect(displayBuffer.lineForRow(1).text).toBe '1a'
          expect(displayBuffer.lineForRow(2).text).toBe 'b'
          expect(displayBuffer.lineForRow(2).fold).toBeUndefined()
          expect(displayBuffer.lineForRow(3).text).toBe 'c'

      describe "when the old range follows a fold", ->
        it "re-positions the screen ranges for the change event based on the preceding fold", ->
          buffer.change([[10, 0], [11, 0]], 'abc')

          expect(displayBuffer.lineForRow(1).text).toBe "1"
          expect(displayBuffer.lineForRow(2).fold).toBe fold1
          expect(displayBuffer.lineForRow(3).text).toBe "5"
          expect(displayBuffer.lineForRow(4).fold).toBe fold2
          expect(displayBuffer.lineForRow(5).text).toMatch /^9-+/

          expect(changeHandler).toHaveBeenCalledWith(start: 6, end: 7, screenDelta: -1, bufferDelta: -1)

      describe "when the old range is inside a fold", ->
        describe "when the end of the new range precedes the end of the fold", ->
          it "updates the fold and ensures the change is present when the fold is destroyed", ->
            buffer.insert([3, 0], '\n')
            expect(fold1.getStartRow()).toBe 2
            expect(fold1.getEndRow()).toBe 5

            expect(displayBuffer.lineForRow(1).text).toBe "1"
            expect(displayBuffer.lineForRow(2).text).toBe "2"
            expect(displayBuffer.lineForRow(2).fold).toBe fold1
            expect(displayBuffer.lineForRow(3).text).toMatch "5"
            expect(displayBuffer.lineForRow(4).fold).toBe fold2
            expect(displayBuffer.lineForRow(5).text).toMatch /^9-+/

            expect(changeHandler).toHaveBeenCalledWith(start: 2, end: 2, screenDelta: 0, bufferDelta: 1)

        describe "when the end of the new range exceeds the end of the fold", ->
          it "expands the fold to contain all the inserted lines", ->
            buffer.change([[3, 0], [4, 0]], 'a\nb\nc\nd\n')
            expect(fold1.getStartRow()).toBe 2
            expect(fold1.getEndRow()).toBe 7

            expect(displayBuffer.lineForRow(1).text).toBe "1"
            expect(displayBuffer.lineForRow(2).text).toBe "2"
            expect(displayBuffer.lineForRow(2).fold).toBe fold1
            expect(displayBuffer.lineForRow(3).text).toMatch "5"
            expect(displayBuffer.lineForRow(4).fold).toBe fold2
            expect(displayBuffer.lineForRow(5).text).toMatch /^9-+/

            expect(changeHandler).toHaveBeenCalledWith(start: 2, end: 2, screenDelta: 0, bufferDelta: 3)

      describe "when the old range straddles the end of the fold", ->
        describe "when the end of the new range precedes the end of the fold", ->
          it "destroys the fold", ->
            fold2.destroy()
            buffer.change([[3, 0], [6, 0]], 'a\n')
            expect(displayBuffer.lineForRow(2).text).toBe '2'
            expect(displayBuffer.lineForRow(2).fold).toBeUndefined()
            expect(displayBuffer.lineForRow(3).text).toBe 'a'
            expect(displayBuffer.lineForRow(4).text).toBe '6'

      describe "when the old range is contained to a single line in-between two folds", ->
        it "re-renders the line with the placeholder and re-positions the second fold", ->
          buffer.insert([5, 0], 'abc\n')

          expect(displayBuffer.lineForRow(1).text).toBe "1"
          expect(displayBuffer.lineForRow(2).fold).toBe fold1
          expect(displayBuffer.lineForRow(3).text).toMatch "abc"
          expect(displayBuffer.lineForRow(4).text).toBe "5"
          expect(displayBuffer.lineForRow(5).fold).toBe fold2
          expect(displayBuffer.lineForRow(6).text).toMatch /^9-+/

          expect(changeHandler).toHaveBeenCalledWith(start: 3, end: 3, screenDelta: 1, bufferDelta: 1)

    describe "position translation", ->
      it "translates positions to account for folded lines and characters and the placeholder", ->
        fold = displayBuffer.createFold(4, 7)

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

        # clip screen positions before translating
        expect(displayBuffer.bufferPositionForScreenPosition([-5, -5])).toEqual([0, 0])
        expect(displayBuffer.bufferPositionForScreenPosition([Infinity, Infinity])).toEqual([200, 0])

        # after fold is destroyed
        fold.destroy()

        expect(displayBuffer.screenPositionForBufferPosition([8, 0])).toEqual [8, 0]
        expect(displayBuffer.screenPositionForBufferPosition([11, 2])).toEqual [11, 2]

        expect(displayBuffer.bufferPositionForScreenPosition([5, 0])).toEqual [5, 0]
        expect(displayBuffer.bufferPositionForScreenPosition([9, 2])).toEqual [9, 2]

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
        expect(displayBuffer.clipScreenPosition([0, tabLength])).toEqual [0, tabLength]

    describe "when skipAtomicTokens is true", ->
      it "clips screen positions in the middle of atomic tab characters to the end of the character", ->
        buffer.insert([0, 0], '\t')
        expect(displayBuffer.clipScreenPosition([0, 0], skipAtomicTokens: true)).toEqual [0, 0]
        expect(displayBuffer.clipScreenPosition([0, 1], skipAtomicTokens: true)).toEqual [0, tabLength]
        expect(displayBuffer.clipScreenPosition([0, tabLength], skipAtomicTokens: true)).toEqual [0, tabLength]

  describe "position translation in the presence of hard tabs", ->
    it "correctly translates positions on either side of a tab", ->
      buffer.setText('\t')
      expect(displayBuffer.screenPositionForBufferPosition([0, 1])).toEqual [0, 2]
      expect(displayBuffer.bufferPositionForScreenPosition([0, 2])).toEqual [0, 1]

  describe ".getMaxLineLength()", ->
    it "returns the length of the longest screen line", ->
      expect(displayBuffer.getMaxLineLength()).toBe 65
      buffer.delete([[6, 0], [6, 65]])
      expect(displayBuffer.getMaxLineLength()).toBe 62

  describe "markers", ->
    beforeEach ->
      displayBuffer.createFold(4, 7)

    describe "marker creation and manipulation", ->
      it "allows markers to be created in terms of both screen and buffer coordinates", ->
        marker1 = displayBuffer.markScreenRange([[5, 4], [5, 10]])
        marker2 = displayBuffer.markBufferRange([[8, 4], [8, 10]])
        expect(marker1.getBufferRange()).toEqual [[8, 4], [8, 10]]
        expect(marker2.getScreenRange()).toEqual [[5, 4], [5, 10]]

      it "emits a 'marker-created' event on the DisplayBuffer whenever a marker is created", ->
        displayBuffer.on 'marker-created', markerCreatedHandler = jasmine.createSpy("markerCreatedHandler")

        marker1 = displayBuffer.markScreenRange([[5, 4], [5, 10]])
        expect(markerCreatedHandler).toHaveBeenCalledWith(marker1)
        markerCreatedHandler.reset()

        marker2 = buffer.markRange([[5, 4], [5, 10]])
        expect(markerCreatedHandler).toHaveBeenCalledWith(displayBuffer.getMarker(marker2.id))

      it "allows marker head and tail positions to be manipulated in both screen and buffer coordinates", ->
        marker = displayBuffer.markScreenRange([[5, 4], [5, 10]])
        marker.setHeadScreenPosition([5, 4])
        marker.setTailBufferPosition([5, 4])
        expect(marker.isReversed()).toBeFalsy()
        expect(marker.getBufferRange()).toEqual [[5, 4], [8, 4]]
        marker.setHeadBufferPosition([5, 4])
        marker.setTailScreenPosition([5, 4])
        expect(marker.isReversed()).toBeTruthy()
        expect(marker.getBufferRange()).toEqual [[5, 4], [8, 4]]

      it "returns whether a position changed when it is assigned", ->
        marker = displayBuffer.markScreenRange([[0, 0], [0, 0]])
        expect(marker.setHeadScreenPosition([5, 4])).toBeTruthy()
        expect(marker.setHeadScreenPosition([5, 4])).toBeFalsy()
        expect(marker.setHeadBufferPosition([1, 0])).toBeTruthy()
        expect(marker.setHeadBufferPosition([1, 0])).toBeFalsy()
        expect(marker.setTailScreenPosition([5, 4])).toBeTruthy()
        expect(marker.setTailScreenPosition([5, 4])).toBeFalsy()
        expect(marker.setTailBufferPosition([1, 0])).toBeTruthy()
        expect(marker.setTailBufferPosition([1, 0])).toBeFalsy()

    describe "marker change events", ->
      [markerChangedHandler, marker] = []

      beforeEach ->
        marker = displayBuffer.markScreenRange([[5, 4], [5, 10]])
        marker.on 'changed', markerChangedHandler = jasmine.createSpy("markerChangedHandler")

      it "triggers the 'changed' event whenever the markers head's screen position changes in the buffer or on screen", ->
        marker.setHeadScreenPosition([8, 20])
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(markerChangedHandler.argsForCall[0][0]).toEqual {
          oldHeadScreenPosition: [5, 10]
          oldHeadBufferPosition: [8, 10]
          newHeadScreenPosition: [8, 20]
          newHeadBufferPosition: [11, 20]
          oldTailScreenPosition: [5, 4]
          oldTailBufferPosition: [8, 4]
          newTailScreenPosition: [5, 4]
          newTailBufferPosition: [8, 4]
          bufferChanged: false
          valid: true
        }
        markerChangedHandler.reset()

        buffer.insert([11, 0], '...')
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(markerChangedHandler.argsForCall[0][0]).toEqual {
          oldHeadScreenPosition: [8, 20]
          oldHeadBufferPosition: [11, 20]
          newHeadScreenPosition: [8, 23]
          newHeadBufferPosition: [11, 23]
          oldTailScreenPosition: [5, 4]
          oldTailBufferPosition: [8, 4]
          newTailScreenPosition: [5, 4]
          newTailBufferPosition: [8, 4]
          bufferChanged: true
          valid: true
        }
        markerChangedHandler.reset()

        displayBuffer.destroyFoldsContainingBufferRow(4)
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(markerChangedHandler.argsForCall[0][0]).toEqual {
          oldHeadScreenPosition: [8, 23]
          oldHeadBufferPosition: [11, 23]
          newHeadScreenPosition: [11, 23]
          newHeadBufferPosition: [11, 23]
          oldTailScreenPosition: [5, 4]
          oldTailBufferPosition: [8, 4]
          newTailScreenPosition: [8, 4]
          newTailBufferPosition: [8, 4]
          bufferChanged: false
          valid: true
        }
        markerChangedHandler.reset()

        displayBuffer.createFold(4, 7)
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(markerChangedHandler.argsForCall[0][0]).toEqual {
          oldHeadScreenPosition: [11, 23]
          oldHeadBufferPosition: [11, 23]
          newHeadScreenPosition: [8, 23]
          newHeadBufferPosition: [11, 23]
          oldTailScreenPosition: [8, 4]
          oldTailBufferPosition: [8, 4]
          newTailScreenPosition: [5, 4]
          newTailBufferPosition: [8, 4]
          bufferChanged: false
          valid: true
        }

      it "triggers the 'changed' event whenever the marker tail's position changes in the buffer or on screen", ->
        marker.setTailScreenPosition([8, 20])
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(markerChangedHandler.argsForCall[0][0]).toEqual {
          oldHeadScreenPosition: [5, 10]
          oldHeadBufferPosition: [8, 10]
          newHeadScreenPosition: [5, 10]
          newHeadBufferPosition: [8, 10]
          oldTailScreenPosition: [5, 4]
          oldTailBufferPosition: [8, 4]
          newTailScreenPosition: [8, 20]
          newTailBufferPosition: [11, 20]
          bufferChanged: false
          valid: true
        }
        markerChangedHandler.reset()

        buffer.insert([11, 0], '...')
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(markerChangedHandler.argsForCall[0][0]).toEqual {
          oldHeadScreenPosition: [5, 10]
          oldHeadBufferPosition: [8, 10]
          newHeadScreenPosition: [5, 10]
          newHeadBufferPosition: [8, 10]
          oldTailScreenPosition: [8, 20]
          oldTailBufferPosition: [11, 20]
          newTailScreenPosition: [8, 23]
          newTailBufferPosition: [11, 23]
          bufferChanged: true
          valid: true
        }

      it "triggers the 'changed' event whenever the marker is invalidated or revalidated", ->
        buffer.deleteRow(8)
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(markerChangedHandler.argsForCall[0][0]).toEqual {
          oldHeadScreenPosition: [5, 10]
          oldHeadBufferPosition: [8, 10]
          newHeadScreenPosition: [5, 10]
          newHeadBufferPosition: [8, 10]
          oldTailScreenPosition: [5, 4]
          oldTailBufferPosition: [8, 4]
          newTailScreenPosition: [5, 4]
          newTailBufferPosition: [8, 4]
          bufferChanged: true
          valid: false
        }

        markerChangedHandler.reset()
        buffer.undo()

        expect(markerChangedHandler).toHaveBeenCalled()
        expect(markerChangedHandler.argsForCall[0][0]).toEqual {
          oldHeadScreenPosition: [5, 10]
          oldHeadBufferPosition: [8, 10]
          newHeadScreenPosition: [5, 10]
          newHeadBufferPosition: [8, 10]
          oldTailScreenPosition: [5, 4]
          oldTailBufferPosition: [8, 4]
          newTailScreenPosition: [5, 4]
          newTailBufferPosition: [8, 4]
          bufferChanged: true
          valid: true
        }

      it "does not call the callback for screen changes that don't change the position of the marker", ->
        displayBuffer.createFold(10, 11)
        expect(markerChangedHandler).not.toHaveBeenCalled()

      it "updates markers before emitting buffer change events, but does not notify their observers until the change event", ->
        marker2 = displayBuffer.markBufferRange([[8, 1], [8, 1]])
        marker2.on 'changed', marker2ChangedHandler = jasmine.createSpy("marker2ChangedHandler")
        displayBuffer.on 'changed', changeHandler = jasmine.createSpy("changeHandler").andCallFake -> onDisplayBufferChange()

        # New change ----

        onDisplayBufferChange = ->
          # calls change handler first
          expect(markerChangedHandler).not.toHaveBeenCalled()
          expect(marker2ChangedHandler).not.toHaveBeenCalled()
          # but still updates the markers
          expect(marker.getScreenRange()).toEqual [[5, 7], [5, 13]]
          expect(marker.getHeadScreenPosition()).toEqual [5, 13]
          expect(marker.getTailScreenPosition()).toEqual [5, 7]
          expect(marker2.isValid()).toBeFalsy()

        buffer.change([[8, 0], [8, 2]], ".....")
        expect(changeHandler).toHaveBeenCalled()
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(marker2ChangedHandler).toHaveBeenCalled()

        # Undo change ----

        changeHandler.reset()
        markerChangedHandler.reset()
        marker2ChangedHandler.reset()

        marker3 = displayBuffer.markBufferRange([[8, 1], [8, 2]])
        marker3.on 'changed', marker3ChangedHandler = jasmine.createSpy("marker3ChangedHandler")

        onDisplayBufferChange = ->
          # calls change handler first
          expect(markerChangedHandler).not.toHaveBeenCalled()
          expect(marker2ChangedHandler).not.toHaveBeenCalled()
          expect(marker3ChangedHandler).not.toHaveBeenCalled()
          # but still updates the markers
          expect(marker.getScreenRange()).toEqual [[5, 4], [5, 10]]
          expect(marker.getHeadScreenPosition()).toEqual [5, 10]
          expect(marker.getTailScreenPosition()).toEqual [5, 4]
          expect(marker2.isValid()).toBeTruthy()
          expect(marker3.isValid()).toBeFalsy()

        buffer.undo()
        expect(changeHandler).toHaveBeenCalled()
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(marker2ChangedHandler).toHaveBeenCalled()
        expect(marker3ChangedHandler).toHaveBeenCalled()

        # Redo change ----

        changeHandler.reset()
        markerChangedHandler.reset()
        marker2ChangedHandler.reset()
        marker3ChangedHandler.reset()

        onDisplayBufferChange = ->
          # calls change handler first
          expect(markerChangedHandler).not.toHaveBeenCalled()
          expect(marker2ChangedHandler).not.toHaveBeenCalled()
          expect(marker3ChangedHandler).not.toHaveBeenCalled()
          # but still updates the markers
          expect(marker.getScreenRange()).toEqual [[5, 7], [5, 13]]
          expect(marker.getHeadScreenPosition()).toEqual [5, 13]
          expect(marker.getTailScreenPosition()).toEqual [5, 7]
          expect(marker2.isValid()).toBeFalsy()
          expect(marker3.isValid()).toBeTruthy()

        buffer.redo()
        expect(changeHandler).toHaveBeenCalled()
        expect(markerChangedHandler).toHaveBeenCalled()
        expect(marker2ChangedHandler).toHaveBeenCalled()
        expect(marker3ChangedHandler).toHaveBeenCalled()

      it "updates the position of markers before emitting change events that aren't caused by a buffer change", ->
        displayBuffer.on 'changed', changeHandler = jasmine.createSpy("changeHandler").andCallFake ->
          # calls change handler first
          expect(markerChangedHandler).not.toHaveBeenCalled()
          # but still updates the markers
          expect(marker.getScreenRange()).toEqual [[8, 4], [8, 10]]
          expect(marker.getHeadScreenPosition()).toEqual [8, 10]
          expect(marker.getTailScreenPosition()).toEqual [8, 4]

        displayBuffer.destroyFoldsContainingBufferRow(4)

        expect(changeHandler).toHaveBeenCalled()
        expect(markerChangedHandler).toHaveBeenCalled()

    describe ".findMarkers(attributes)", ->
      it "allows the startBufferRow and endBufferRow to be specified", ->
        marker1 = displayBuffer.markBufferRange([[0, 0], [3, 0]], class: 'a')
        marker2 = displayBuffer.markBufferRange([[0, 0], [5, 0]], class: 'a')
        marker3 = displayBuffer.markBufferRange([[9, 0], [10, 0]], class: 'b')

        expect(displayBuffer.findMarkers(class: 'a', startBufferRow: 0)).toEqual [marker2, marker1]
        expect(displayBuffer.findMarkers(class: 'a', startBufferRow: 0, endBufferRow: 3)).toEqual [marker1]
        expect(displayBuffer.findMarkers(endBufferRow: 10)).toEqual [marker3]

    describe "marker destruction", ->
      it "allows markers to be destroyed", ->
        marker = displayBuffer.markScreenRange([[5, 4], [5, 10]])
        marker.destroy()
        expect(marker.isValid()).toBeFalsy()
        expect(displayBuffer.getMarker(marker.id)).toBeUndefined()

      it "emits 'destroyed' events when markers are destroyed", ->
        destroyedHandler = jasmine.createSpy("destroyedHandler")
        marker = displayBuffer.markScreenRange([[5, 4], [5, 10]])
        marker.on 'destroyed', destroyedHandler
        marker.destroy()
        expect(destroyedHandler).toHaveBeenCalled()
        destroyedHandler.reset()

        marker2 = displayBuffer.markScreenRange([[5, 4], [5, 10]])
        marker2.on 'destroyed', destroyedHandler
        buffer.getMarker(marker2.id).destroy()
        expect(destroyedHandler).toHaveBeenCalled()
