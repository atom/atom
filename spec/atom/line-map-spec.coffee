LineMap = require 'line-map'
ScreenLineFragment = require 'screen-line-fragment'
Input = require 'buffer'
Highlighter = require 'highlighter'
Point = require 'point'

describe "LineMap", ->
  [highlighter, map] = []
  [line0, line1, line2, line3, line4] = []

  beforeEach ->
    buffer = new Input(require.resolve 'fixtures/sample.js')
    highlighter = new Highlighter(buffer)
    map = new LineMap
    [line0, line1, line2, line3, line4] = highlighter.linesForScreenRows(0, 4)

  describe ".insertAtInputRow(row, lineFragments)", ->
    it "inserts the given line fragments before the specified buffer row", ->
      map.insertAtInputRow(0, [line2, line3])
      map.insertAtInputRow(0, [line0, line1])
      map.insertAtInputRow(4, [line4])

      expect(map.lineForOutputRow(0)).toEqual line0
      expect(map.lineForOutputRow(1)).toEqual line1
      expect(map.lineForOutputRow(2)).toEqual line2
      expect(map.lineForOutputRow(3)).toEqual line3
      expect(map.lineForOutputRow(4)).toEqual line4

    it "allows for partial line fragments on the row following the insertion", ->
      [line0a, line0b] = line0.splitAt(10)
      map.insertAtInputRow(0, [line0a, line0b])
      map.insertAtInputRow(0, [line1])

      expect(map.lineForOutputRow(0)).toEqual line1
      expect(map.lineForOutputRow(1)).toEqual line0a.concat(line0b)


  describe ".spliceAtInputRow(bufferRow, rowCount, lineFragments)", ->
    describe "when called with a row count of 0", ->
      it "inserts the given line fragments before the specified buffer row", ->
        map.insertAtInputRow(0, [line0, line1])
        map.spliceAtInputRow(1, 0, [line3, line4])

        expect(map.lineForOutputRow(0)).toEqual line0
        expect(map.lineForOutputRow(1)).toEqual line3
        expect(map.lineForOutputRow(2)).toEqual line4
        expect(map.lineForOutputRow(3)).toEqual line1

        map.spliceAtInputRow(0, 0, [line2])
        expect(map.lineForOutputRow(0)).toEqual line2

    describe "when called with a row count of 1", ->
      describe "when the specified buffer row is spanned by a single line fragment", ->
        it "replaces the spanning line fragment with the given line fragments", ->
          map.insertAtInputRow(0, [line0, line1, line2])
          map.spliceAtInputRow(1, 1, [line3, line4])

          expect(map.inputLineCount()).toBe 4
          expect(map.lineForOutputRow(0)).toEqual line0
          expect(map.lineForOutputRow(1)).toEqual line3
          expect(map.lineForOutputRow(2)).toEqual line4
          expect(map.lineForOutputRow(3)).toEqual line2

          map.spliceAtInputRow(2, 1, [line0])
          expect(map.lineForOutputRow(2)).toEqual line0
          expect(map.lineForOutputRow(3)).toEqual line2

      describe "when the specified buffer row is spanned by multiple line fragments", ->
        it "replaces all spanning line fragments with the given line fragments", ->
          [line1a, line1b] = line1.splitAt(10)
          [line3a, line3b] = line3.splitAt(10)

          map.insertAtInputRow(0, [line0, line1a, line1b, line2])
          map.spliceAtInputRow(1, 1, [line3a, line3b, line4])

          expect(map.inputLineCount()).toBe 4
          expect(map.lineForOutputRow(0)).toEqual line0
          expect(map.lineForOutputRow(1)).toEqual line3a.concat(line3b)
          expect(map.lineForOutputRow(2)).toEqual line4
          expect(map.lineForOutputRow(3)).toEqual line2

      describe "when the row following the specified buffer row is spanned by multiple line fragments", ->
        it "replaces the specified row, but no portion of the following row", ->
          [line3a, line3b] = line3.splitAt(10)

          map.insertAtInputRow(0, [line0, line1, line2, line3a, line3b])
          map.spliceAtInputRow(2, 1, [line4])

          expect(map.lineForOutputRow(0)).toEqual line0
          expect(map.lineForOutputRow(1)).toEqual line1
          expect(map.lineForOutputRow(2)).toEqual line4
          expect(map.lineForOutputRow(3)).toEqual line3a.concat(line3b)

    describe "when called with a row count greater than 1", ->
      it "replaces all line fragments spanning the multiple buffer rows with the given line fragments", ->
        [line1a, line1b] = line1.splitAt(10)
        [line3a, line3b] = line3.splitAt(10)

        map.insertAtInputRow(0, [line0, line1a, line1b, line2])
        map.spliceAtInputRow(1, 2, [line3a, line3b, line4])

        expect(map.inputLineCount()).toBe 3
        expect(map.lineForOutputRow(0)).toEqual line0
        expect(map.lineForOutputRow(1)).toEqual line3a.concat(line3b)
        expect(map.lineForOutputRow(2)).toEqual line4

  describe ".spliceAtOutputRow(startRow, rowCount, lineFragemnts)", ->
    describe "when called with a row count of 0", ->
      it "inserts the given line fragments before the specified buffer row", ->
        map.insertAtInputRow(0, [line0, line1, line2])
        map.spliceAtOutputRow(1, 0, [line3, line4])

        expect(map.lineForOutputRow(0)).toEqual line0
        expect(map.lineForOutputRow(1)).toEqual line3
        expect(map.lineForOutputRow(2)).toEqual line4
        expect(map.lineForOutputRow(3)).toEqual line1
        expect(map.lineForOutputRow(4)).toEqual line2

    describe "when called with a row count of 1", ->
      describe "when the specified output row is spanned by a single line fragment", ->
        it "replaces the spanning line fragment with the given line fragments", ->
          map.insertAtInputRow(0, [line0, line1, line2])
          map.spliceAtOutputRow(1, 1, [line3, line4])

          expect(map.inputLineCount()).toBe 4
          expect(map.lineForOutputRow(0)).toEqual line0
          expect(map.lineForOutputRow(1)).toEqual line3
          expect(map.lineForOutputRow(2)).toEqual line4
          expect(map.lineForOutputRow(3)).toEqual line2

      describe "when the specified output row is spanned by multiple line fragments", ->
        it "replaces all spanning line fragments with the given line fragments", ->
          [line0a, line0b] = line0.splitAt(10)
          [line3a, line3b] = line3.splitAt(10)

          map.insertAtInputRow(0, [line0a, line0b, line1, line2])
          map.spliceAtOutputRow(0, 1, [line3a, line3b, line4])

          expect(map.inputLineCount()).toBe 4
          expect(map.lineForOutputRow(0)).toEqual line3a.concat(line3b)
          expect(map.lineForOutputRow(1)).toEqual line4
          expect(map.lineForOutputRow(2)).toEqual line1
          expect(map.lineForOutputRow(3)).toEqual line2

    describe "when called with a row count greater than 1", ->
      it "replaces all line fragments spanning the multiple buffer rows with the given line fragments", ->
        [line1a, line1b] = line1.splitAt(10)
        [line3a, line3b] = line3.splitAt(10)

        map.insertAtInputRow(0, [line0, line1a, line1b, line2])
        map.spliceAtOutputRow(1, 2, [line3a, line3b, line4])

        expect(map.inputLineCount()).toBe 3
        expect(map.lineForOutputRow(0)).toEqual line0
        expect(map.lineForOutputRow(1)).toEqual line3a.concat(line3b)
        expect(map.lineForOutputRow(2)).toEqual line4

  describe ".linesForOutputRows(startRow, endRow)", ->
    it "returns lines for the given row range, concatenating fragments that belong on a single output line", ->
      [line1a, line1b] = line1.splitAt(11)
      [line3a, line3b] = line3.splitAt(16)
      map.insertAtInputRow(0, [line0, line1a, line1b, line2, line3a, line3b, line4])
      expect(map.linesForOutputRows(1, 3)).toEqual [line1, line2, line3]
      # repeating assertion to cover a regression where this method mutated lines
      expect(map.linesForOutputRows(1, 3)).toEqual [line1, line2, line3]

  describe ".lineForInputRow(bufferRow)", ->
    it "returns the concatenated output line fragments that comprise the given buffer row", ->
      line1Text = line1.text
      [line1a, line1b] = line1.splitAt(11)
      line1a.outputDelta = new Point(1, 0)

      map.insertAtInputRow(0, [line0, line1a, line1b, line2])

      expect(map.lineForInputRow(0).text).toBe line0.text
      expect(map.lineForInputRow(1).text).toBe line1Text

  describe ".outputPositionForInputPosition(bufferPosition)", ->
    beforeEach ->
      # line1a-line3b describes a fold
      [line1a, line1b] = line1.splitAt(10)
      [line3a, line3b] = line3.splitAt(20)
      line1a.inputDelta.row = 2
      line1a.inputDelta.column = 20

      # line4a-line4b describes a wrapped line
      [line4a, line4b] = line4.splitAt(20)
      line4a.outputDelta = new Point(1, 0)

      map.insertAtInputRow(0, [line0, line1a, line3b, line4a, line4b])

    it "translates the given buffer position based on buffer and output deltas of the line fragments in the map", ->
      expect(map.outputPositionForInputPosition([0, 0])).toEqual [0, 0]
      expect(map.outputPositionForInputPosition([0, 5])).toEqual [0, 5]
      expect(map.outputPositionForInputPosition([1, 5])).toEqual [1, 5]
      expect(map.outputPositionForInputPosition([3, 20])).toEqual [1, 10]
      expect(map.outputPositionForInputPosition([3, 30])).toEqual [1, 20]
      expect(map.outputPositionForInputPosition([4, 5])).toEqual [2, 5]

    it "wraps buffer positions at the end of a output line to the end end of the next output line", ->
      expect(map.outputPositionForInputPosition([4, 20])).toEqual [3, 0]

  describe ".outputLineCount()", ->
    it "returns the total of all inserted output row deltas", ->
      [line1a, line1b] = line1.splitAt(10)
      [line3a, line3b] = line3.splitAt(10)
      line1a.outputDelta = new Point(1, 0)
      line3a.outputDelta = new Point(1, 0)

      map.insertAtInputRow(0, [line0, line1a, line1b, line2])

      expect(map.outputLineCount()).toBe 4

