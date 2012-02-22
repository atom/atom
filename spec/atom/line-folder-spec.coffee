Buffer = require 'buffer'
Higlighter = require 'highlighter'
LineFolder = require 'line-folder'
Range = require 'range'

describe "LineFolder", ->
  [buffer, folder] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    highlighter = new Higlighter(buffer)
    folder = new LineFolder(highlighter)

  describe "screen line rendering", ->
    describe "when there is a single fold spanning multiple lines", ->
      it "renders a placeholder on the first line of a fold, and skips subsequent lines", ->
        folder.fold(new Range([4, 29], [7, 4]))
        [line4, line5] = fragments = folder.linesForScreenRows(4, 5)

        expect(line4.text).toBe '    while(items.length > 0) {...}'
        expect(line5.text).toBe '    return sort(left).concat(pivot).concat(sort(right));'

    describe "when there is a single fold contained on a single line", ->
      it "renders a placeholder for the folded region, but does not skip any lines", ->
        folder.fold(new Range([2, 8], [2, 25]))
        [line2, line3] = folder.linesForScreenRows(2, 3)

        expect(line2.text).toBe '    if (...) return items;'
        expect(line3.text).toBe '    var pivot = items.shift(), current, left = [], right = [];'

    describe "when there is a nested fold on the last line of another fold", ->
      it "does not render a placeholder for the nested fold because it is inside of the other fold", ->
        folder.fold(new Range([8, 5], [8, 10]))
        folder.fold(new Range([4, 29], [8, 36]))
        [line4, line5] = folder.linesForScreenRows(4, 5)

        expect(line4.text).toBe '    while(items.length > 0) {...concat(sort(right));'
        expect(line5.text).toBe '  };'

    describe "when another fold begins on the last line of a fold", ->
      describe "when the second fold is created before the first fold", ->
        it "renders a placeholder for both folds on the first line of the first fold", ->
          folder.fold(new Range([7, 5], [8, 36]))
          folder.fold(new Range([4, 29], [7, 4]))
          [line4, line5] = folder.linesForScreenRows(4, 5)

          expect(line4.text).toBe  '    while(items.length > 0) {...}...concat(sort(right));'
          expect(line5.text).toBe '  };'

      describe "when the second fold is created after the first fold", ->
        it "renders a placeholder for both folds on the first line of the first fold", ->
          folder.fold(new Range([4, 29], [7, 4]))
          folder.fold(new Range([7, 5], [8, 36]))
          [line4, line5] = folder.linesForScreenRows(4, 5)
          expect(line4.text).toBe  '    while(items.length > 0) {...}...concat(sort(right));'
          expect(line5.text).toBe '  };'

  fdescribe "position translation", ->
    describe "when there is single fold spanning multiple lines", ->
      it "translates positions to account for folded lines and characters and the placeholder", ->
        folder.fold(new Range([4, 29], [7, 4]))

        # preceding fold: identity
        expect(folder.screenPositionForBufferPosition([3, 0])).toEqual [3, 0]
        expect(folder.screenPositionForBufferPosition([4, 0])).toEqual [4, 0]
        expect(folder.screenPositionForBufferPosition([4, 29])).toEqual [4, 29]

        expect(folder.bufferPositionForScreenPosition([3, 0])).toEqual [3, 0]
        expect(folder.bufferPositionForScreenPosition([4, 0])).toEqual [4, 0]
        expect(folder.bufferPositionForScreenPosition([4, 29])).toEqual [4, 29]

        # inside of fold: translate to the start of the fold
        # expect(folder.screenPositionForBufferPosition([4, 30])).toEqual [4, 29]
        # expect(folder.screenPositionForBufferPosition([5, 5])).toEqual [4, 29]

        # following fold, on last line of fold
        expect(folder.screenPositionForBufferPosition([7, 4])).toEqual [4, 32]
        expect(folder.screenPositionForBufferPosition([7, 7])).toEqual [4, 35]

        expect(folder.bufferPositionForScreenPosition([4, 32])).toEqual [7, 4]
        expect(folder.bufferPositionForScreenPosition([4, 35])).toEqual [7, 7]

        # # following fold, subsequent line
        expect(folder.screenPositionForBufferPosition([8, 0])).toEqual [5, 0]
        expect(folder.screenPositionForBufferPosition([13, 13])).toEqual [10, 13]

        expect(folder.bufferPositionForScreenPosition([5, 0])).toEqual [8, 0]
        expect(folder.bufferPositionForScreenPosition([10, 13])).toEqual [13, 13]

    describe "when there is a single fold spanning a single line", ->
      it "translates positions to account for folded characters and the placeholder", ->
        folder.fold(new Range([4, 10], [4, 15]))

        expect(folder.screenPositionForBufferPosition([4, 5])).toEqual [4, 5]
        expect(folder.screenPositionForBufferPosition([4, 15])).toEqual [4, 13]
        expect(folder.screenPositionForBufferPosition([4, 20])).toEqual [4, 18]

        expect(folder.bufferPositionForScreenPosition([4, 5])).toEqual [4, 5]
        expect(folder.bufferPositionForScreenPosition([4, 13])).toEqual [4, 15]
        expect(folder.bufferPositionForScreenPosition([4, 18])).toEqual [4, 20]
