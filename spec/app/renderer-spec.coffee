Renderer = require 'renderer'
Buffer = require 'buffer'

describe "Renderer", ->
  [renderer, buffer, changeHandler, tabText] = []
  beforeEach ->
    tabText = '  '
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    renderer = new Renderer(buffer, {tabText})
    changeHandler = jasmine.createSpy 'changeHandler'
    renderer.on 'change', changeHandler

  describe "soft wrapping", ->
    beforeEach ->
      renderer.setMaxLineLength(50)
      changeHandler.reset()

    describe "rendering of soft-wrapped lines", ->
      describe "when the line is shorter than the max line length", ->
        it "renders the line unchanged", ->
          expect(renderer.lineForRow(0).text).toBe buffer.lineForRow(0)

      describe "when the line is empty", ->
        it "renders the empty line", ->
          expect(renderer.lineForRow(13).text).toBe ''

      describe "when there is a non-whitespace character at the max length boundary", ->
        describe "when there is whitespace before the boundary", ->
          it "wraps the line at the end of the first whitespace preceding the boundary", ->
            expect(renderer.lineForRow(10).text).toBe '    return '
            expect(renderer.lineForRow(11).text).toBe 'sort(left).concat(pivot).concat(sort(right));'

        describe "when there is no whitespace before the boundary", ->
          it "wraps the line exactly at the boundary since there's no more graceful place to wrap it", ->
            buffer.change([[0, 0], [1, 0]], 'abcdefghijklmnopqrstuvwxyz\n')
            renderer.setMaxLineLength(10)
            expect(renderer.lineForRow(0).text).toBe 'abcdefghij'
            expect(renderer.lineForRow(1).text).toBe 'klmnopqrst'
            expect(renderer.lineForRow(2).text).toBe 'uvwxyz'

      describe "when there is a whitespace character at the max length boundary", ->
        it "wraps the line at the first non-whitespace character following the boundary", ->
          expect(renderer.lineForRow(3).text).toBe '    var pivot = items.shift(), current, left = [], '
          expect(renderer.lineForRow(4).text).toBe 'right = [];'

      describe "when a fold is created on the last screen line of a wrapped buffer line", ->
        it "inserts the placeholder in the correct location and fires a change event", ->
          fold = renderer.createFold([[3, 52], [3, 56]])
          expect(renderer.lineForRow(3).text).toBe '    var pivot = items.shift(), current, left = [], '
          expect(renderer.lineForRow(4).text).toBe 'r... = [];'
          expect(renderer.lineForRow(5).text).toBe '    while(items.length > 0) {'

          expect(changeHandler).toHaveBeenCalled()
          [[event]]= changeHandler.argsForCall
          expect(event.oldRange).toEqual([[3, 0], [4, 11]])
          expect(event.newRange).toEqual([[3, 0], [4, 10]])

          changeHandler.reset()
          fold.destroy()

          expect(renderer.lineForRow(3).text).toBe '    var pivot = items.shift(), current, left = [], '
          expect(renderer.lineForRow(4).text).toBe 'right = [];'
          expect(renderer.lineForRow(5).text).toBe '    while(items.length > 0) {'

          expect(changeHandler).toHaveBeenCalled()
          [[event]]= changeHandler.argsForCall
          expect(event.oldRange).toEqual([[3, 0], [4, 10]])
          expect(event.newRange).toEqual([[3, 0], [4, 11]])

      describe "when a fold is created on the penultimate screen line of a wrapped buffer line", ->
        beforeEach ->
          renderer.setMaxLineLength(36)
          changeHandler.reset()

        it "inserts the placeholder in the correct location and fires a change event", ->
          fold = renderer.createFold([[6, 29], [6, 33]])
          expect(renderer.lineForRow(8).text).toBe "      current < pivot ? "
          expect(renderer.lineForRow(9).text).toBe "left....(current) : "
          expect(renderer.lineForRow(10).text).toBe "right.push(current);"

          expect(changeHandler).toHaveBeenCalled()
          [[event]]= changeHandler.argsForCall
          expect(event.oldRange).toEqual([[8, 0], [10, 20]])
          expect(event.newRange).toEqual([[8, 0], [10, 20]])

          changeHandler.reset()
          fold.destroy()

          expect(changeHandler).toHaveBeenCalled()
          [[event]]= changeHandler.argsForCall
          expect(event.oldRange).toEqual([[8, 0], [10, 20]])
          expect(event.newRange).toEqual([[8, 0], [10, 20]])

      describe "when a fold ends on the penultimate screen line of a wrapped buffer line", ->
        beforeEach ->
          renderer.setMaxLineLength(36)
          changeHandler.reset()

        it "inserts the placeholder in the correct location and fires a change event", ->
          fold = renderer.createFold([[5, 0], [6, 29]])
          expect(renderer.lineForRow(6).text).toBe "    while(items.length > 0) {"
          expect(renderer.lineForRow(7).text).toBe "...push(current) : "
          expect(renderer.lineForRow(8).text).toBe "right.push(current);"

          expect(changeHandler).toHaveBeenCalled()
          [[event]]= changeHandler.argsForCall
          expect(event.oldRange).toEqual([[7, 0], [10, 20]])
          expect(event.newRange).toEqual([[7, 0], [8, 20]])

          changeHandler.reset()
          fold.destroy()

          expect(changeHandler).toHaveBeenCalled()
          [[event]]= changeHandler.argsForCall
          expect(event.oldRange).toEqual([[7, 0], [8, 20]])
          expect(event.newRange).toEqual([[7, 0], [10, 20]])

      describe "when there is a fold placeholder straddling the max length boundary", ->
        it "wraps the line before the fold placeholder", ->
          renderer.createFold([[3, 49], [6, 1]])

          expect(renderer.lineForRow(3).text).toBe '    var pivot = items.shift(), current, left = []'
          expect(renderer.lineForRow(4).text).toBe '...     current < pivot ? left.push(current) : '
          expect(renderer.lineForRow(5).text).toBe 'right.push(current);'
          expect(renderer.lineForRow(6).text).toBe '    }'

          renderer.createFold([[6, 56], [8, 15]])
          expect(renderer.lineForRow(5).text).toBe 'right.push(...(left).concat(pivot).concat(sort(rig'
          expect(renderer.lineForRow(6).text).toBe 'ht));'
          expect(renderer.lineForRow(7).text).toBe '  };'

      describe "when there is a fold placeholder ending at the max length boundary", ->
        it "wraps the line after the fold placeholder", ->
          renderer.createFold([[3, 47], [3, 51]])
          expect(renderer.lineForRow(3).text).toBe '    var pivot = items.shift(), current, left = ...'
          expect(renderer.lineForRow(4).text).toBe 'right = [];'

    describe "when the buffer changes", ->
      describe "when buffer lines are updated", ->
        describe "when the update makes a soft-wrapped line shorter than the max line length", ->
          it "rewraps the line and emits a change event", ->
            buffer.delete([[6, 24], [6, 42]])
            expect(renderer.lineForRow(7).text).toBe '      current < pivot ?  : right.push(current);'
            expect(renderer.lineForRow(8).text).toBe '    }'

            expect(changeHandler).toHaveBeenCalled()
            [[event]]= changeHandler.argsForCall
            expect(event.oldRange).toEqual([[7, 0], [8, 20]])
            expect(event.newRange).toEqual([[7, 0], [7, 47]])

        describe "when the update causes a line to softwrap an additional time", ->
          it "rewraps the line and emits a change event", ->
            buffer.insert([6, 28], '1234567890')
            expect(renderer.lineForRow(7).text).toBe '      current < pivot ? '
            expect(renderer.lineForRow(8).text).toBe 'left1234567890.push(current) : '
            expect(renderer.lineForRow(9).text).toBe 'right.push(current);'
            expect(renderer.lineForRow(10).text).toBe '    }'

            expect(changeHandler).toHaveBeenCalled()
            [[event]] = changeHandler.argsForCall
            expect(event.oldRange).toEqual([[7, 0], [8, 20]])
            expect(event.newRange).toEqual([[7, 0], [9, 20]])

      describe "when buffer lines are inserted", ->
        it "inserts / updates wrapped lines and emits a change event", ->
          buffer.insert([6, 21], '1234567890 abcdefghij 1234567890\nabcdefghij')
          expect(renderer.lineForRow(7).text).toBe '      current < pivot1234567890 abcdefghij '
          expect(renderer.lineForRow(8).text).toBe '1234567890'
          expect(renderer.lineForRow(9).text).toBe 'abcdefghij ? left.push(current) : '
          expect(renderer.lineForRow(10).text).toBe 'right.push(current);'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[7, 0], [8, 20]])
          expect(event.newRange).toEqual([[7, 0], [10, 20]])

      describe "when buffer lines are removed", ->
        it "removes lines and emits a change event", ->
          buffer.change([[3, 21], [7, 5]], ';')
          expect(renderer.lineForRow(3).text).toBe '    var pivot = items;'
          expect(renderer.lineForRow(4).text).toBe '    return '
          expect(renderer.lineForRow(5).text).toBe 'sort(left).concat(pivot).concat(sort(right));'
          expect(renderer.lineForRow(6).text).toBe '  };'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[3, 0], [11, 45]])
          expect(event.newRange).toEqual([[3, 0], [5, 45]])

    describe "position translation", ->
      it "translates positions accounting for wrapped lines", ->
        # before any wrapped lines
        expect(renderer.screenPositionForBufferPosition([0, 5])).toEqual([0, 5])
        expect(renderer.bufferPositionForScreenPosition([0, 5])).toEqual([0, 5])
        expect(renderer.screenPositionForBufferPosition([0, 29])).toEqual([0, 29])
        expect(renderer.bufferPositionForScreenPosition([0, 29])).toEqual([0, 29])

        # on a wrapped line
        expect(renderer.screenPositionForBufferPosition([3, 5])).toEqual([3, 5])
        expect(renderer.bufferPositionForScreenPosition([3, 5])).toEqual([3, 5])
        expect(renderer.screenPositionForBufferPosition([3, 50])).toEqual([3, 50])
        expect(renderer.screenPositionForBufferPosition([3, 51])).toEqual([4, 0])
        expect(renderer.bufferPositionForScreenPosition([4, 0])).toEqual([3, 51])
        expect(renderer.bufferPositionForScreenPosition([3, 50])).toEqual([3, 50])
        expect(renderer.screenPositionForBufferPosition([3, 62])).toEqual([4, 11])
        expect(renderer.bufferPositionForScreenPosition([4, 11])).toEqual([3, 62])

        # following a wrapped line
        expect(renderer.screenPositionForBufferPosition([4, 5])).toEqual([5, 5])
        expect(renderer.bufferPositionForScreenPosition([5, 5])).toEqual([4, 5])

    describe ".setMaxLineLength(length)", ->
      it "changes the length at which lines are wrapped and emits a change event for all screen lines", ->
        renderer.setMaxLineLength(40)
        expect(tokensText renderer.lineForRow(4).tokens).toBe 'left = [], right = [];'
        expect(tokensText renderer.lineForRow(5).tokens).toBe '    while(items.length > 0) {'
        expect(tokensText renderer.lineForRow(12).tokens).toBe 'sort(left).concat(pivot).concat(sort(rig'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual([[0, 0], [15, 2]])
        expect(event.newRange).toEqual([[0, 0], [18, 2]])

  describe "folding", ->
    beforeEach ->
      buffer = new Buffer(require.resolve 'fixtures/two-hundred.txt')
      renderer = new Renderer(buffer, {tabText})
      renderer.on 'change', changeHandler

    describe "when folds are created and destroyed", ->
      describe "when a fold spans multiple lines", ->
        it "replaces the lines spanned by the fold with a placeholder that references the fold object", ->
          fold = renderer.createFold(4, 7)

          [line4, line5] = renderer.linesForRows(4, 5)
          expect(line4.fold).toBe fold
          expect(line4.text).toMatch /^4-+/
          expect(line4.bufferDelta).toEqual [4, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toBe '8'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual [[4, 0], [7, 1]]
          expect(event.newRange).toEqual [[4, 0], [4, 101]]
          changeHandler.reset()

          fold.destroy()
          [line4, line5] = renderer.linesForRows(4, 5)
          expect(line4.fold).toBeUndefined()
          expect(line4.text).toMatch /^4-+/
          expect(line4.bufferDelta).toEqual [1, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toBe '5'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 101]]
          expect(event.newRange).toEqual [[4, 0], [7, 1]]

      describe "when a fold spans a single line", ->
        it "renders a fold placeholder for the folded line but does not skip any lines", ->
          fold = renderer.createFold(4, 4)

          [line4, line5] = renderer.linesForRows(4, 5)
          expect(line4.fold).toBe fold
          expect(line4.text).toMatch /^4-+/
          expect(line4.bufferDelta).toEqual [1, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toBe '5'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 101]]
          expect(event.newRange).toEqual [[4, 0], [4, 101]]
          changeHandler.reset()

          fold.destroy()

          [line4, line5] = renderer.linesForRows(4, 5)
          expect(line4.fold).toBeUndefined()
          expect(line4.text).toMatch /^4-+/
          expect(line4.bufferDelta).toEqual [1, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toBe '5'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 101]]
          expect(event.newRange).toEqual [[4, 0], [4, 101]]
          changeHandler.reset()

      describe "when a fold is nested within another fold", ->
        it "does not render the placeholder for the inner fold until the outer fold is destroyed", ->
          innerFold = renderer.createFold(6, 7)
          outerFold = renderer.createFold(4, 8)

          [line4, line5] = renderer.linesForRows(4, 5)
          expect(line4.fold).toBe outerFold
          expect(line4.text).toMatch /4-+/
          expect(line4.bufferDelta).toEqual [5, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toMatch /9-+/

          outerFold.destroy()

          [line4, line5, line6, line7] = renderer.linesForRows(4, 7)
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
          innerFold = renderer.createFold(4, 6)
          outerFold = renderer.createFold(4, 8)

          [line4, line5] = renderer.linesForRows(4, 5)
          expect(line4.fold).toBe outerFold
          expect(line4.text).toMatch /4-+/
          expect(line4.bufferDelta).toEqual [5, 0]
          expect(line4.screenDelta).toEqual [1, 0]
          expect(line5.text).toMatch /9-+/

    describe "when the buffer changes", ->
      [fold1, fold2] = []
      beforeEach ->
        fold1 = renderer.createFold([[4, 29], [7, 4]])
        fold2 = renderer.createFold([[7, 5], [8, 36]])
        changeHandler.reset()

      describe "when the old range precedes lines with a fold", ->
        it "updates the buffer and re-positions subsequent folds", ->
          buffer.change([[1, 5], [2, 10]], 'abc')

          expect(renderer.lineForRow(1).text).toBe '  varabcems.length <= 1) return items;'
          expect(renderer.lineForRow(3).text).toBe '    while(items.length > 0) {...}...concat(sort(right));'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[1, 0], [2, 40]]
          expect(event.newRange).toEqual [[1, 0], [1, 38]]
          changeHandler.reset()

          fold1.destroy()
          expect(renderer.lineForRow(3).text).toBe '    while(items.length > 0) {'
          expect(renderer.lineForRow(6).text).toBe '    }...concat(sort(right));'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[3, 0], [3, 56]]
          expect(event.newRange).toEqual [[3, 0], [6, 28]]

      describe "when the old range follows lines with a fold", ->
        it "re-positions the screen ranges for the change event based on the preceding fold", ->
          buffer.change([[9, 3], [10, 0]], 'abc')

          expect(renderer.lineForRow(5).text).toBe '  }abc'
          expect(renderer.lineForRow(6).text).toBe '  return sort(Array.apply(this, arguments));'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[5, 0], [6, 0]]
          expect(event.newRange).toEqual [[5, 0], [5, 6]]

      describe "when the old range contains unfolded text on the first line of a fold, preceding the fold placeholder", ->
        it "re-renders the line with the placeholder and re-positions the fold", ->
          buffer.change([[4, 4], [4, 9]], 'slongaz')

          expect(renderer.lineForRow(4).text).toBe '    slongaz(items.length > 0) {...}...concat(sort(right));'
          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 56]]
          expect(event.newRange).toEqual [[4, 0], [4, 58]]

          fold1.destroy()
          expect(renderer.lineForRow(4).text).toBe '    slongaz(items.length > 0) {'

      describe "when the old range is contained to a single line in-between two fold placeholders", ->
        it "re-renders the line with the placeholder and re-positions the second fold", ->
          buffer.insert([7, 4], 'abc')
          expect(renderer.lineForRow(4).text).toBe '    while(items.length > 0) {...abc}...concat(sort(right));'
          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 56]]
          expect(event.newRange).toEqual [[4, 0], [4, 59]]

          fold2.destroy()
          expect(renderer.lineForRow(4).text).toBe '    while(items.length > 0) {...abc}'

      describe "when the old range is inside a fold", ->
        it "does not trigger a change event, but updates the fold and ensures the change is present when the fold is destroyed", ->
          buffer.change([[4, 29], [6, 0]], 'abc')

          expect(renderer.lineForRow(4).text).toBe '    while(items.length > 0) {...}...concat(sort(right));'
          expect(changeHandler).not.toHaveBeenCalled()

          fold1.destroy()
          expect(renderer.lineForRow(4).text).toBe '    while(items.length > 0) {abc      current < pivot ? left.push(current) : right.push(current);'
          expect(renderer.lineForRow(5).text).toBe '    }...concat(sort(right));'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 56]]
          expect(event.newRange).toEqual [[4, 0], [5, 28]]

      describe "when the old range surrounds a fold", ->
        it "removes the fold and replaces the fold placeholder with the new text", ->
          buffer.change([[4, 29], [7, 4]], 'party()')

          expect(renderer.lineForRow(4).text).toBe '    while(items.length > 0) {party()}...concat(sort(right));'
          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 56]]
          expect(event.newRange).toEqual [[4, 0], [4, 60]]

      describe "when the old range surrounds two nested folds", ->
        it "removes both folds and replaces the fold placeholder with the new text", ->
          renderer.createFold([[4, 25], [7, 5]])
          buffer.change([[4, 25], [7, 5]], '4)')

          expect(renderer.lineForRow(4).text).toBe '    while(items.length > 4)...concat(sort(right));'
          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 56]]
          expect(event.newRange).toEqual [[4, 0], [4, 51]]

    describe "position translation", ->
      describe "when there is single fold spanning multiple lines", ->
        it "translates positions to account for folded lines and characters and the placeholder", ->
          renderer.createFold([[4, 29], [7, 4]])

          # preceding fold: identity
          expect(renderer.screenPositionForBufferPosition([3, 0])).toEqual [3, 0]
          expect(renderer.screenPositionForBufferPosition([4, 0])).toEqual [4, 0]
          expect(renderer.screenPositionForBufferPosition([4, 29])).toEqual [4, 29]

          expect(renderer.bufferPositionForScreenPosition([3, 0])).toEqual [3, 0]
          expect(renderer.bufferPositionForScreenPosition([4, 0])).toEqual [4, 0]
          expect(renderer.bufferPositionForScreenPosition([4, 29])).toEqual [4, 29]

          # inside of fold: translate to the start of the fold
          expect(renderer.screenPositionForBufferPosition([4, 35])).toEqual [4, 29]
          expect(renderer.screenPositionForBufferPosition([5, 5])).toEqual [4, 29]

          # following fold, on last line of fold
          expect(renderer.screenPositionForBufferPosition([7, 4])).toEqual [4, 32]
          expect(renderer.bufferPositionForScreenPosition([4, 32])).toEqual [7, 4]

          # # following fold, subsequent line
          expect(renderer.screenPositionForBufferPosition([8, 0])).toEqual [5, 0]
          expect(renderer.screenPositionForBufferPosition([11, 13])).toEqual [8, 13]

          expect(renderer.bufferPositionForScreenPosition([5, 0])).toEqual [8, 0]
          expect(renderer.bufferPositionForScreenPosition([9, 2])).toEqual [12, 2]

      describe "when there is a single fold spanning a single line", ->
        it "translates positions to account for folded characters and the placeholder", ->
          renderer.createFold([[4, 10], [4, 15]])

          expect(renderer.screenPositionForBufferPosition([4, 5])).toEqual [4, 5]
          expect(renderer.bufferPositionForScreenPosition([4, 5])).toEqual [4, 5]

          expect(renderer.screenPositionForBufferPosition([4, 15])).toEqual [4, 13]
          expect(renderer.bufferPositionForScreenPosition([4, 13])).toEqual [4, 15]

          expect(renderer.screenPositionForBufferPosition([4, 20])).toEqual [4, 18]
          expect(renderer.bufferPositionForScreenPosition([4, 18])).toEqual [4, 20]

      describe "when there is a fold on a wrapped line", ->
        it "translates positions accounting for both the fold and the wrapped line", ->
          renderer.setMaxLineLength(50)
          renderer.createFold([[3, 51], [3, 58]])
          expect(renderer.screenPositionForBufferPosition([3, 58])).toEqual [4, 3]
          expect(renderer.bufferPositionForScreenPosition([4, 3])).toEqual [3, 58]

  describe ".clipScreenPosition(screenPosition, wrapBeyondNewlines: false, wrapAtSoftNewlines: false, skipAtomicTokens: false)", ->
    beforeEach ->
      renderer.setMaxLineLength(50)

    it "allows valid positions", ->
      expect(renderer.clipScreenPosition([4, 5])).toEqual [4, 5]
      expect(renderer.clipScreenPosition([4, 11])).toEqual [4, 11]

    it "disallows negative positions", ->
      expect(renderer.clipScreenPosition([-1, -1])).toEqual [0, 0]
      expect(renderer.clipScreenPosition([-1, 10])).toEqual [0, 0]
      expect(renderer.clipScreenPosition([0, -1])).toEqual [0, 0]

    it "disallows positions beyond the last row", ->
      expect(renderer.clipScreenPosition([1000, 0])).toEqual [15, 2]
      expect(renderer.clipScreenPosition([1000, 1000])).toEqual [15, 2]

    describe "when wrapBeyondNewlines is false (the default)", ->
      it "wraps positions beyond the end of hard newlines to the end of the line", ->
        expect(renderer.clipScreenPosition([1, 10000])).toEqual [1, 30]
        expect(renderer.clipScreenPosition([4, 30])).toEqual [4, 11]
        expect(renderer.clipScreenPosition([4, 1000])).toEqual [4, 11]

    describe "when wrapBeyondNewlines is true", ->
      it "wraps positions past the end of hard newlines to the next line", ->
        expect(renderer.clipScreenPosition([0, 29], wrapBeyondNewlines: true)).toEqual [0, 29]
        expect(renderer.clipScreenPosition([0, 30], wrapBeyondNewlines: true)).toEqual [1, 0]
        expect(renderer.clipScreenPosition([0, 1000], wrapBeyondNewlines: true)).toEqual [1, 0]

    describe "when wrapAtSoftNewlines is false (the default)", ->
      it "clips positions at the end of soft-wrapped lines to the character preceding the end of the line", ->
        expect(renderer.clipScreenPosition([3, 50])).toEqual [3, 50]
        expect(renderer.clipScreenPosition([3, 51])).toEqual [3, 50]
        expect(renderer.clipScreenPosition([3, 58])).toEqual [3, 50]
        expect(renderer.clipScreenPosition([3, 1000])).toEqual [3, 50]

      describe "if there is a fold placeholder at the very end of the screen line", ->
        it "clips positions at the end of the screen line to the position preceding the placeholder", ->
          renderer.createFold([[3, 47], [3, 51]])
          expect(renderer.clipScreenPosition([3, 50])).toEqual [3, 47]

    describe "when wrapAtSoftNewlines is true", ->
      it "wraps positions at the end of soft-wrapped lines to the next screen line", ->
        expect(renderer.clipScreenPosition([3, 50], wrapAtSoftNewlines: true)).toEqual [3, 50]
        expect(renderer.clipScreenPosition([3, 51], wrapAtSoftNewlines: true)).toEqual [4, 0]
        expect(renderer.clipScreenPosition([3, 58], wrapAtSoftNewlines: true)).toEqual [4, 0]
        expect(renderer.clipScreenPosition([3, 1000], wrapAtSoftNewlines: true)).toEqual [4, 0]

    describe "when skipAtomicTokens is false (the default)", ->
      it "clips screen positions in the middle of fold placeholders to the to the beginning of fold placeholders", ->
        renderer.createFold([[3, 55], [3, 59]])
        expect(renderer.clipScreenPosition([4, 5])).toEqual [4, 4]
        expect(renderer.clipScreenPosition([4, 6])).toEqual [4, 4]
        expect(renderer.clipScreenPosition([4, 7])).toEqual [4, 7]

      it "clips screen positions in the middle of atomic tab characters to the beginning of the character", ->
        buffer.insert([0, 0], '\t')
        expect(renderer.clipScreenPosition([0, 0])).toEqual [0, 0]
        expect(renderer.clipScreenPosition([0, 1])).toEqual [0, 0]
        expect(renderer.clipScreenPosition([0, tabText.length])).toEqual [0, tabText.length]

    describe "when skipAtomicTokens is true", ->
      it "wraps the screen positions in the middle of fold placeholders to the end of the placeholder", ->
        renderer.createFold([[3, 55], [3, 59]])
        expect(renderer.clipScreenPosition([4, 4], skipAtomicTokens: true)).toEqual [4, 4]
        expect(renderer.clipScreenPosition([4, 5], skipAtomicTokens: true)).toEqual [4, 7]
        expect(renderer.clipScreenPosition([4, 6], skipAtomicTokens: true)).toEqual [4, 7]

      it "clips screen positions in the middle of atomic tab characters to the beginning of the character", ->
        buffer.insert([0, 0], '\t')
        expect(renderer.clipScreenPosition([0, 0], skipAtomicTokens: true)).toEqual [0, 0]
        expect(renderer.clipScreenPosition([0, 1], skipAtomicTokens: true)).toEqual [0, tabText.length]
        expect(renderer.clipScreenPosition([0, tabText.length], skipAtomicTokens: true)).toEqual [0, tabText.length]

  describe ".bufferRowsForScreenRows()", ->
    it "returns the buffer rows corresponding to each screen row in the given range", ->
      renderer.setMaxLineLength(50)
      renderer.createFold(4, 7)
      expect(renderer.bufferRowsForScreenRows()).toEqual [0, 1, 2, 3, 3, 4, 8, 8, 9, 10, 11, 12]
