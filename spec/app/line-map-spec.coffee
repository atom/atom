LineMap = require 'line-map'
ScreenLine = require 'screen-line'
Buffer = require 'buffer'
LanguageMode = require 'language-mode'
Point = require 'point'

describe "LineMap", ->
  [languageMode, map] = []
  [line0, line1, line2, line3, line4] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    languageMode = new LanguageMode(buffer)
    map = new LineMap
    [line0, line1, line2, line3, line4] = languageMode.linesForScreenRows(0, 4)

  describe ".insertAtBufferRow(row, lineFragments)", ->
    it "inserts the given line fragments before the specified buffer row", ->
      map.insertAtBufferRow(0, [line2, line3])
      map.insertAtBufferRow(0, [line0, line1])
      map.insertAtBufferRow(4, [line4])

      expect(map.lineForScreenRow(0)).toEqual line0
      expect(map.lineForScreenRow(1)).toEqual line1
      expect(map.lineForScreenRow(2)).toEqual line2
      expect(map.lineForScreenRow(3)).toEqual line3
      expect(map.lineForScreenRow(4)).toEqual line4

    it "allows for partial line fragments on the row following the insertion", ->
      [line0a, line0b] = line0.splitAt(10)
      map.insertAtBufferRow(0, [line0a, line0b])
      map.insertAtBufferRow(0, [line1])

      expect(map.lineForScreenRow(0)).toEqual line1
      expect(map.lineForScreenRow(1)).toEqual line0a.concat(line0b)

  describe ".spliceAtBufferRow(bufferRow, rowCount, lineFragments)", ->
    describe "when called with a row count of 0", ->
      it "inserts the given line fragments before the specified buffer row", ->
        map.insertAtBufferRow(0, [line0, line1])
        map.spliceAtBufferRow(1, 0, [line3, line4])

        expect(map.lineForScreenRow(0)).toEqual line0
        expect(map.lineForScreenRow(1)).toEqual line3
        expect(map.lineForScreenRow(2)).toEqual line4
        expect(map.lineForScreenRow(3)).toEqual line1

        map.spliceAtBufferRow(0, 0, [line2])
        expect(map.lineForScreenRow(0)).toEqual line2

    describe "when called with a row count of 1", ->
      describe "when the specified buffer row is spanned by a single line fragment", ->
        it "replaces the spanning line fragment with the given line fragments", ->
          map.insertAtBufferRow(0, [line0, line1, line2])
          map.spliceAtBufferRow(1, 1, [line3, line4])

          expect(map.bufferLineCount()).toBe 4
          expect(map.lineForScreenRow(0)).toEqual line0
          expect(map.lineForScreenRow(1)).toEqual line3
          expect(map.lineForScreenRow(2)).toEqual line4
          expect(map.lineForScreenRow(3)).toEqual line2

          map.spliceAtBufferRow(2, 1, [line0])
          expect(map.lineForScreenRow(2)).toEqual line0
          expect(map.lineForScreenRow(3)).toEqual line2

      describe "when the specified buffer row is spanned by multiple line fragments", ->
        it "replaces all spanning line fragments with the given line fragments", ->
          [line1a, line1b] = line1.splitAt(10)
          [line3a, line3b] = line3.splitAt(10)

          map.insertAtBufferRow(0, [line0, line1a, line1b, line2])
          map.spliceAtBufferRow(1, 1, [line3a, line3b, line4])

          expect(map.bufferLineCount()).toBe 4
          expect(map.lineForScreenRow(0)).toEqual line0
          expect(map.lineForScreenRow(1)).toEqual line3a.concat(line3b)
          expect(map.lineForScreenRow(2)).toEqual line4
          expect(map.lineForScreenRow(3)).toEqual line2

      describe "when the row following the specified buffer row is spanned by multiple line fragments", ->
        it "replaces the specified row, but no portion of the following row", ->
          [line3a, line3b] = line3.splitAt(10)

          map.insertAtBufferRow(0, [line0, line1, line2, line3a, line3b])
          map.spliceAtBufferRow(2, 1, [line4])

          expect(map.lineForScreenRow(0)).toEqual line0
          expect(map.lineForScreenRow(1)).toEqual line1
          expect(map.lineForScreenRow(2)).toEqual line4
          expect(map.lineForScreenRow(3)).toEqual line3a.concat(line3b)

    describe "when called with a row count greater than 1", ->
      it "replaces all line fragments spanning the multiple buffer rows with the given line fragments", ->
        [line1a, line1b] = line1.splitAt(10)
        [line3a, line3b] = line3.splitAt(10)

        map.insertAtBufferRow(0, [line0, line1a, line1b, line2])
        map.spliceAtBufferRow(1, 2, [line3a, line3b, line4])

        expect(map.bufferLineCount()).toBe 3
        expect(map.lineForScreenRow(0)).toEqual line0
        expect(map.lineForScreenRow(1)).toEqual line3a.concat(line3b)
        expect(map.lineForScreenRow(2)).toEqual line4

  describe ".spliceAtScreenRow(startRow, rowCount, lineFragemnts)", ->
    describe "when called with a row count of 0", ->
      it "inserts the given line fragments before the specified buffer row", ->
        map.insertAtBufferRow(0, [line0, line1, line2])
        map.spliceAtScreenRow(1, 0, [line3, line4])

        expect(map.lineForScreenRow(0)).toEqual line0
        expect(map.lineForScreenRow(1)).toEqual line3
        expect(map.lineForScreenRow(2)).toEqual line4
        expect(map.lineForScreenRow(3)).toEqual line1
        expect(map.lineForScreenRow(4)).toEqual line2

    describe "when called with a row count of 1", ->
      describe "when the specified screen row is spanned by a single line fragment", ->
        it "replaces the spanning line fragment with the given line fragments", ->
          map.insertAtBufferRow(0, [line0, line1, line2])
          map.spliceAtScreenRow(1, 1, [line3, line4])

          expect(map.bufferLineCount()).toBe 4
          expect(map.lineForScreenRow(0)).toEqual line0
          expect(map.lineForScreenRow(1)).toEqual line3
          expect(map.lineForScreenRow(2)).toEqual line4
          expect(map.lineForScreenRow(3)).toEqual line2

      describe "when the specified screen row is spanned by multiple line fragments", ->
        it "replaces all spanning line fragments with the given line fragments", ->
          [line0a, line0b] = line0.splitAt(10)
          [line3a, line3b] = line3.splitAt(10)

          map.insertAtBufferRow(0, [line0a, line0b, line1, line2])
          map.spliceAtScreenRow(0, 1, [line3a, line3b, line4])

          expect(map.bufferLineCount()).toBe 4
          expect(map.lineForScreenRow(0)).toEqual line3a.concat(line3b)
          expect(map.lineForScreenRow(1)).toEqual line4
          expect(map.lineForScreenRow(2)).toEqual line1
          expect(map.lineForScreenRow(3)).toEqual line2

    describe "when called with a row count greater than 1", ->
      it "replaces all line fragments spanning the multiple buffer rows with the given line fragments", ->
        [line1a, line1b] = line1.splitAt(10)
        [line3a, line3b] = line3.splitAt(10)

        map.insertAtBufferRow(0, [line0, line1a, line1b, line2])
        map.spliceAtScreenRow(1, 2, [line3a, line3b, line4])

        expect(map.bufferLineCount()).toBe 3
        expect(map.lineForScreenRow(0)).toEqual line0
        expect(map.lineForScreenRow(1)).toEqual line3a.concat(line3b)
        expect(map.lineForScreenRow(2)).toEqual line4

  describe ".linesForScreenRows(startRow, endRow)", ->
    it "returns lines for the given row range, concatenating fragments that belong on a single screen line", ->
      [line1a, line1b] = line1.splitAt(11)
      [line3a, line3b] = line3.splitAt(16)
      map.insertAtBufferRow(0, [line0, line1a, line1b, line2, line3a, line3b, line4])
      expect(map.linesForScreenRows(1, 3)).toEqual [line1, line2, line3]
      # repeating assertion to cover a regression where this method mutated lines
      expect(map.linesForScreenRows(1, 3)).toEqual [line1, line2, line3]

  describe ".lineForBufferRow(bufferRow)", ->
    it "returns the concatenated screen line fragments that comprise the given buffer row", ->
      line1Text = line1.text
      [line1a, line1b] = line1.splitAt(11)
      line1a.screenDelta = new Point(1, 0)

      map.insertAtBufferRow(0, [line0, line1a, line1b, line2])

      expect(map.lineForBufferRow(0).text).toBe line0.text
      expect(map.lineForBufferRow(1).text).toBe line1Text

  describe ".screenPositionForBufferPosition(bufferPosition)", ->
    beforeEach ->
      # line1a-line3b describes a fold
      [line1a, line1b] = line1.splitAt(10)
      [line3a, line3b] = line3.splitAt(20)
      line1a.bufferDelta.row = 2
      line1a.bufferDelta.column = 20

      # line4a-line4b describes a wrapped line
      [line4a, line4b] = line4.splitAt(20)
      line4a.screenDelta = new Point(1, 0)

      map.insertAtBufferRow(0, [line0, line1a, line3b, line4a, line4b])

    it "translates the given buffer position based on buffer and screen deltas of the line fragments in the map", ->
      expect(map.screenPositionForBufferPosition([0, 0])).toEqual [0, 0]
      expect(map.screenPositionForBufferPosition([0, 5])).toEqual [0, 5]
      expect(map.screenPositionForBufferPosition([1, 5])).toEqual [1, 5]
      expect(map.screenPositionForBufferPosition([3, 20])).toEqual [1, 10]
      expect(map.screenPositionForBufferPosition([3, 30])).toEqual [1, 20]
      expect(map.screenPositionForBufferPosition([4, 5])).toEqual [2, 5]

    it "wraps buffer positions at the end of a screen line to the end end of the next screen line", ->
      expect(map.screenPositionForBufferPosition([4, 20])).toEqual [3, 0]

  describe ".screenLineCount()", ->
    it "returns the total of all inserted screen row deltas", ->
      [line1a, line1b] = line1.splitAt(10)
      [line3a, line3b] = line3.splitAt(10)
      line1a.screenDelta = new Point(1, 0)
      line3a.screenDelta = new Point(1, 0)

      map.insertAtBufferRow(0, [line0, line1a, line1b, line2])

      expect(map.screenLineCount()).toBe 4

