Buffer = require 'buffer'
Higlighter = require 'highlighter'
LineFolder = require 'line-folder'
Range = require 'range'

describe "LineFolder", ->
  [buffer, folder, changeHandler] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    highlighter = new Higlighter(buffer)
    folder = new LineFolder(highlighter)
    changeHandler = jasmine.createSpy('changeHandler')
    folder.on 'change', changeHandler

  describe "when folds are created and removed", ->
    it "emits 'fold' and 'unfold' events", ->
      foldHandler = jasmine.createSpy 'foldHandler'
      unfoldHandler = jasmine.createSpy 'unfoldHandler'
      folder.on 'fold', foldHandler
      folder.on 'unfold', unfoldHandler

      foldRange = new Range([4, 29], [7, 4])
      fold = folder.createFold(foldRange)

      expect(foldHandler).toHaveBeenCalled()
      [[range]] = foldHandler.argsForCall
      expect(range).toEqual foldRange

      fold.destroy()
      expect(unfoldHandler).toHaveBeenCalled()
      [[range]] = unfoldHandler.argsForCall
      expect(range).toEqual foldRange

    describe "when there is a single fold spanning multiple lines", ->
      it "replaces folded lines with a single line containing a placeholder and emits a change event", ->
        [line4, line5] = folder.linesForScreenRows(4, 5)
        previousLine4Text = line4.text
        previousLine5Text = line5.text

        fold = folder.createFold(new Range([4, 29], [7, 4]))
        [line4, line5] = folder.linesForScreenRows(4, 5)

        expect(line4.text).toBe '    while(items.length > 0) {...}'
        expect(line5.text).toBe '    return sort(left).concat(pivot).concat(sort(right));'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual [[4, 0], [7, 5]]
        expect(event.newRange).toEqual [[4, 0], [4, 33]]
        changeHandler.reset()

        fold.destroy()
        [line4, line5] = folder.linesForScreenRows(4, 5)
        expect(line4.text).toBe previousLine4Text
        expect(line5.text).toBe previousLine5Text

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual [[4, 0], [4, 33]]
        expect(event.newRange).toEqual [[4, 0], [7, 5]]

    describe "when there is a single fold contained on a single line", ->
      it "renders a placeholder for the folded region, but does not skip any lines", ->
        fold = folder.createFold(new Range([2, 8], [2, 25]))

        [line2, line3] = folder.linesForScreenRows(2, 3)
        expect(line2.text).toBe '    if (...) return items;'
        expect(line3.text).toBe '    var pivot = items.shift(), current, left = [], right = [];'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual [[2, 0], [2, 40]]
        expect(event.newRange).toEqual [[2, 0], [2, 26]]
        changeHandler.reset()

        fold.destroy()

        [line2, line3] = folder.linesForScreenRows(2, 3)
        expect(line2.text).toBe '    if (items.length <= 1) return items;'
        expect(line3.text).toBe '    var pivot = items.shift(), current, left = [], right = [];'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.newRange).toEqual [[2, 0], [2, 40]]
        expect(event.oldRange).toEqual [[2, 0], [2, 26]]
        changeHandler.reset()

    describe "when there is a nested fold", ->
      it "does not render a placeholder for the nested fold because it is inside of the other fold", ->
        folder.createFold(new Range([8, 5], [8, 10]))
        folder.createFold(new Range([4, 29], [8, 36]))
        [line4, line5] = folder.linesForScreenRows(4, 5)

        expect(line4.text).toBe '    while(items.length > 0) {...concat(sort(right));'
        expect(line5.text).toBe '  };'

      it "renders the contents of the outer fold correctly, including the inner fold's placeholder, when the outer fold is destroyed", ->
        fold1 = folder.createFold(new Range([4, 29], [7, 4]))
        fold2 = folder.createFold(new Range([3, 4], [8, 56]))
        fold2.destroy()
        expect(folder.lineForScreenRow(5).text).toBe "    return sort(left).concat(pivot).concat(sort(right));"

      it "allows the outer fold to start at the same location as the inner fold", ->
        fold1 = folder.createFold(new Range([4, 29], [7, 4]))
        fold2 = folder.createFold(new Range([4, 29], [9, 2]))
        expect(folder.lineForScreenRow(4).text).toBe "    while(items.length > 0) {...};"

    describe "when another fold begins on the last line of a fold", ->
      describe "when the second fold is created before the first fold", ->
        it "renders a placeholder for both folds on the first line of the first fold", ->
          fold1 = folder.createFold(new Range([7, 5], [8, 36]))
          fold2 = folder.createFold(new Range([4, 29], [7, 4]))

          [line4, line5] = folder.linesForScreenRows(4, 5)
          expect(line4.text).toBe  '    while(items.length > 0) {...}...concat(sort(right));'
          expect(line5.text).toBe '  };'

          expect(changeHandler.callCount).toBe 2
          [[event1], [event2]] = changeHandler.argsForCall
          expect(event1.oldRange).toEqual [[7, 0], [8, 56]]
          expect(event1.newRange).toEqual [[7, 0], [7, 28]]
          expect(event2.oldRange).toEqual [[4, 0], [7, 28]]
          expect(event2.newRange).toEqual [[4, 0], [4, 56]]
          changeHandler.reset()

          fold1.destroy()
          [line4, line5] = folder.linesForScreenRows(4, 5)
          expect(line4.text).toBe '    while(items.length > 0) {...}'
          expect(line5.text).toBe '    return sort(left).concat(pivot).concat(sort(right));'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual [[4, 0], [4, 56]]
          expect(event.newRange).toEqual [[4, 0], [5, 56]]
          changeHandler.reset()

          fold2.destroy()
          [line4, line5] = folder.linesForScreenRows(4, 5)
          expect(line4.text).toBe '    while(items.length > 0) {'
          expect(line5.text).toBe '      current = items.shift();'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual [[4, 0], [4, 33]]
          expect(event.newRange).toEqual [[4, 0], [7, 5]]

      describe "when the second fold is created after the first fold", ->
        it "renders a placeholder for both folds on the first line of the first fold", ->
          fold1 = folder.createFold(new Range([4, 29], [7, 4]))
          fold2 = folder.createFold(new Range([7, 5], [8, 36]))
          [line4, line5] = folder.linesForScreenRows(4, 5)
          expect(line4.text).toBe  '    while(items.length > 0) {...}...concat(sort(right));'
          expect(line5.text).toBe '  };'

          expect(changeHandler.callCount).toBe 2
          [[event1], [event2]] = changeHandler.argsForCall
          expect(event1.oldRange).toEqual [[4, 0], [7, 5]]
          expect(event1.newRange).toEqual [[4, 0], [4, 33]]
          expect(event2.oldRange).toEqual [[4, 0], [5, 56]]
          expect(event2.newRange).toEqual [[4, 0], [4, 56]]
          changeHandler.reset()

          fold1.destroy()
          [line4, line5] = folder.linesForScreenRows(4, 5)
          [line7] = folder.linesForScreenRows(7, 7)
          expect(line4.text).toBe '    while(items.length > 0) {'
          expect(line5.text).toBe '      current = items.shift();'
          expect(line7.text).toBe '    }...concat(sort(right));'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual [[4, 0], [4, 56]]
          expect(event.newRange).toEqual [[4, 0], [7, 28]]
          changeHandler.reset()

          fold2.destroy()
          [line4, line5] = folder.linesForScreenRows(4, 5)
          expect(line4.text).toBe '    while(items.length > 0) {'
          expect(line5.text).toBe '      current = items.shift();'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual [[7, 0], [7, 28]]
          expect(event.newRange).toEqual [[7, 0], [8, 56]]

      describe "when creating a fold on the first line of an existing fold", ->
        it "renders the line correctly", ->
          folder.createFold(new Range([4, 29], [7, 4]))
          folder.createFold(new Range([4, 10], [4, 26]))
          expect(folder.lineForScreenRow(4).text).toBe '    while(...) {...}'

      describe "when a fold starts at the beginning of a line", ->
        it "renders a placeholder at the beginning of the line", ->
          folder.createFold(new Range([4, 0], [7, 4]))
          expect(folder.lineForScreenRow(4).text).toBe '...}'

      describe "when a fold ends at the beginning of a line", ->
        it "renders a placeholder at the beginning of the line", ->
          folder.createFold(new Range([4, 29], [7, 0]))
          expect(folder.lineForScreenRow(4).text).toBe '    while(items.length > 0) {...    }'

      describe "when a fold starts on the first line of the buffer", ->
        it "renders the first line correctly when the fold is destroyed", ->
          fold = folder.createFold(new Range([0, 14], [0, 27]))
          fold.destroy()
          expect(folder.lineForScreenRow(0).text).toBe 'var quicksort = function () {'

    it "doesn't raise an error when attempting to fold empty ranges", ->
      folder.createFold(new Range([1, 1], [1, 1]))

  describe "when the buffer changes", ->
    [fold1, fold2] = []
    beforeEach ->
      fold1 = folder.createFold(new Range([4, 29], [7, 4]))
      fold2 = folder.createFold(new Range([7, 5], [8, 36]))
      changeHandler.reset()

    describe "when the old range precedes lines with a fold", ->
      it "updates the buffer and re-positions subsequent folds", ->
        buffer.change(new Range([1, 5], [2, 10]), 'abc')

        expect(folder.lineForScreenRow(1).text).toBe '  varabcems.length <= 1) return items;'
        expect(folder.lineForScreenRow(3).text).toBe '    while(items.length > 0) {...}...concat(sort(right));'

        expect(changeHandler).toHaveBeenCalled()
        [[event]] = changeHandler.argsForCall
        expect(event.oldRange).toEqual [[1, 0], [2, 40]]
        expect(event.newRange).toEqual [[1, 0], [1, 38]]
        changeHandler.reset()

        fold1.destroy()
        expect(folder.lineForScreenRow(3).text).toBe '    while(items.length > 0) {'
        expect(folder.lineForScreenRow(6).text).toBe '    }...concat(sort(right));'

        expect(changeHandler).toHaveBeenCalled()
        [[event]] = changeHandler.argsForCall
        expect(event.oldRange).toEqual [[3, 0], [3, 56]]
        expect(event.newRange).toEqual [[3, 0], [6, 28]]

    describe "when the old range follows lines with a fold", ->
      it "re-positions the screen ranges for the change event based on the preceding fold", ->
        buffer.change(new Range([9, 3], [10, 0]), 'abc')

        expect(folder.lineForScreenRow(5).text).toBe '  }abc'
        expect(folder.lineForScreenRow(6).text).toBe '  return sort(Array.apply(this, arguments));'

        expect(changeHandler).toHaveBeenCalled()
        [[event]] = changeHandler.argsForCall
        expect(event.oldRange).toEqual [[5, 0], [6, 0]]
        expect(event.newRange).toEqual [[5, 0], [5, 6]]

    describe "when the old range contains unfolded text on the first line of a fold, preceding the fold placeholder", ->
      it "re-renders the line with the placeholder and re-positions the fold", ->
        buffer.change(new Range([4, 4], [4, 9]), 'slongaz')

        expect(folder.lineForScreenRow(4).text).toBe '    slongaz(items.length > 0) {...}...concat(sort(right));'
        expect(changeHandler).toHaveBeenCalled()
        [[event]] = changeHandler.argsForCall
        expect(event.oldRange).toEqual [[4, 0], [4, 56]]
        expect(event.newRange).toEqual [[4, 0], [4, 58]]

        fold1.destroy()
        expect(folder.lineForScreenRow(4).text).toBe '    slongaz(items.length > 0) {'

    describe "when the old range is contained to a single line in-between two fold placeholders", ->
      it "re-renders the line with the placeholder and re-positions the second fold", ->
        buffer.insert([7, 4], 'abc')
        expect(folder.lineForScreenRow(4).text).toBe '    while(items.length > 0) {...abc}...concat(sort(right));'
        expect(changeHandler).toHaveBeenCalled()
        [[event]] = changeHandler.argsForCall
        expect(event.oldRange).toEqual [[4, 0], [4, 56]]
        expect(event.newRange).toEqual [[4, 0], [4, 59]]

        fold2.destroy()

        expect(folder.lineForScreenRow(4).text).toBe '    while(items.length > 0) {...abc}'

    describe "when the old range is inside a fold", ->
      it "does not trigger a change event, but updates the fold and ensures the change is present when the fold is destroyed", ->
        buffer.change(new Range([4, 29], [6, 0]), 'abc')

        expect(folder.lineForScreenRow(4).text).toBe '    while(items.length > 0) {...}...concat(sort(right));'
        expect(changeHandler).not.toHaveBeenCalled()

        fold1.destroy()
        expect(folder.lineForScreenRow(4).text).toBe '    while(items.length > 0) {abc      current < pivot ? left.push(current) : right.push(current);'
        expect(folder.lineForScreenRow(5).text).toBe '    }...concat(sort(right));'

        expect(changeHandler).toHaveBeenCalled()
        [[event]] = changeHandler.argsForCall
        expect(event.oldRange).toEqual [[4, 0], [4, 56]]
        expect(event.newRange).toEqual [[4, 0], [5, 28]]

    describe "when the old range surrounds a fold", ->
      it "removes the fold and replaces the fold placeholder with the new text", ->
        buffer.change(new Range([4, 29], [7, 4]), 'party()')

        expect(folder.lineForScreenRow(4).text).toBe '    while(items.length > 0) {party()}...concat(sort(right));'
        expect(changeHandler).toHaveBeenCalled()
        [[event]] = changeHandler.argsForCall
        expect(event.oldRange).toEqual [[4, 0], [4, 56]]
        expect(event.newRange).toEqual [[4, 0], [4, 60]]

    describe "when the old range straddles the start of a fold", ->
      it "moves the start of the fold to the end of the new range", ->

    describe "when the old region straddles the end of a fold", ->
      it "moves the start of the fold to the beginning of the new range", ->

  describe "position translation", ->
    describe "when there is single fold spanning multiple lines", ->
      it "translates positions to account for folded lines and characters and the placeholder", ->
        folder.createFold(new Range([4, 29], [7, 4]))

        # preceding fold: identity
        expect(folder.screenPositionForBufferPosition([3, 0])).toEqual [3, 0]
        expect(folder.screenPositionForBufferPosition([4, 0])).toEqual [4, 0]
        expect(folder.screenPositionForBufferPosition([4, 29])).toEqual [4, 29]

        expect(folder.bufferPositionForScreenPosition([3, 0])).toEqual [3, 0]
        expect(folder.bufferPositionForScreenPosition([4, 0])).toEqual [4, 0]
        expect(folder.bufferPositionForScreenPosition([4, 29])).toEqual [4, 29]

        # inside of fold: translate to the start of the fold
        expect(folder.screenPositionForBufferPosition([4, 35])).toEqual [4, 29]
        expect(folder.screenPositionForBufferPosition([5, 5])).toEqual [4, 29]

        # following fold, on last line of fold
        expect(folder.screenPositionForBufferPosition([7, 4])).toEqual [4, 32]
        expect(folder.bufferPositionForScreenPosition([4, 32])).toEqual [7, 4]

        # # following fold, subsequent line
        expect(folder.screenPositionForBufferPosition([8, 0])).toEqual [5, 0]
        expect(folder.screenPositionForBufferPosition([11, 13])).toEqual [8, 13]

        expect(folder.bufferPositionForScreenPosition([5, 0])).toEqual [8, 0]
        expect(folder.bufferPositionForScreenPosition([9, 2])).toEqual [12, 2]

    describe "when there is a single fold spanning a single line", ->
      it "translates positions to account for folded characters and the placeholder", ->
        folder.createFold(new Range([4, 10], [4, 15]))

        expect(folder.screenPositionForBufferPosition([4, 5])).toEqual [4, 5]
        expect(folder.screenPositionForBufferPosition([4, 15])).toEqual [4, 13]
        expect(folder.screenPositionForBufferPosition([4, 20])).toEqual [4, 18]

        expect(folder.bufferPositionForScreenPosition([4, 5])).toEqual [4, 5]
        expect(folder.bufferPositionForScreenPosition([4, 13])).toEqual [4, 15]
        expect(folder.bufferPositionForScreenPosition([4, 18])).toEqual [4, 20]

  describe ".clipScreenPosition(screenPosition)", ->
    beforeEach ->
      folder.createFold(new Range([4, 29], [7, 4]))

    it "returns the nearest valid position based on the current screen lines", ->
      expect(folder.clipScreenPosition([-1, -1])).toEqual [0, 0]
      expect(folder.clipScreenPosition([0, -1])).toEqual [0, 0]
      expect(folder.clipScreenPosition([-1, 5])).toEqual [0, 0]
      expect(folder.clipScreenPosition([1, 10000])).toEqual [1, 30]
      expect(folder.clipScreenPosition([2, 15])).toEqual [2, 15]
      expect(folder.clipScreenPosition([4, 32])).toEqual [4, 32]
      expect(folder.clipScreenPosition([4, 1000])).toEqual [4, 33]
      expect(folder.clipScreenPosition([1000, 1000])).toEqual [9, 2]

    describe "when skipAtomicTokens is false (the default)", ->
      it "clips positions inside a placeholder to the beginning of the placeholder", ->
        expect(folder.clipScreenPosition([4, 30])).toEqual [4, 29]
        expect(folder.clipScreenPosition([4, 31])).toEqual [4, 29]
        expect(folder.clipScreenPosition([4, 32])).toEqual [4, 32]

    describe "when skipAtomicTokens is true", ->
      it "clips positions inside a placeholder to the end of the placeholder", ->
        expect(folder.clipScreenPosition([4, 29], skipAtomicTokens: true)).toEqual [4, 29]
        expect(folder.clipScreenPosition([4, 30], skipAtomicTokens: true)).toEqual [4, 32]
        expect(folder.clipScreenPosition([4, 31], skipAtomicTokens: true)).toEqual [4, 32]
        expect(folder.clipScreenPosition([4, 32], skipAtomicTokens: true)).toEqual [4, 32]

