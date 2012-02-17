LineMap = require 'line-map'
ScreenLineFragment = require 'screen-line-fragment'
Buffer = require 'buffer'
Highlighter = require 'highlighter'

describe "LineMap", ->
  [highlighter, map] = []
  [line0, line1, line2, line3, line4] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    highlighter = new Highlighter(buffer)
    map = new LineMap
    [line0, line1, line2, line3, line4] = highlighter.lineFragmentsForRows(0, 4)

  describe ".insertAtBufferRow(row, lineFragment(s))", ->
    describe "when passed a single, line fragment", ->
      it "inserts the line fragment before the specified buffer row", ->
        map.insertAtBufferRow(0, line1)
        map.insertAtBufferRow(0, line0)
        map.insertAtBufferRow(2, line3)
        map.insertAtBufferRow(2, line2)

        expect(map.lineFragmentsForScreenRow(0)).toEqual [line0]
        expect(map.lineFragmentsForScreenRow(1)).toEqual [line1]
        expect(map.lineFragmentsForScreenRow(2)).toEqual [line2]
        expect(map.lineFragmentsForScreenRow(3)).toEqual [line3]

    describe "when passed an array of line fragments", ->
      it "inserts the given line fragments before the specified buffer row", ->
        map.insertAtBufferRow(0, [line2, line3])
        map.insertAtBufferRow(0, [line0, line1])
        map.insertAtBufferRow(4, [line4])

        expect(map.lineFragmentsForScreenRow(0)).toEqual [line0]
        expect(map.lineFragmentsForScreenRow(1)).toEqual [line1]
        expect(map.lineFragmentsForScreenRow(2)).toEqual [line2]
        expect(map.lineFragmentsForScreenRow(3)).toEqual [line3]
        expect(map.lineFragmentsForScreenRow(4)).toEqual [line4]

  describe ".spliceAtBufferRow(bufferRow, rowCount, lineFragments)", ->
    describe "when called with a row count of 0", ->
      it "inserts the given line fragments before the specified buffer row", ->
        map.insertAtBufferRow(0, [line0, line1, line2])
        map.spliceAtBufferRow(1, 0, [line3, line4])

        expect(map.lineFragmentsForScreenRow(0)).toEqual [line0]
        expect(map.lineFragmentsForScreenRow(1)).toEqual [line3]
        expect(map.lineFragmentsForScreenRow(2)).toEqual [line4]
        expect(map.lineFragmentsForScreenRow(3)).toEqual [line1]
        expect(map.lineFragmentsForScreenRow(4)).toEqual [line2]

    describe "when called with a row count of 1", ->
      describe "when the specified buffer row is spanned by a single line fragment", ->
        it "replaces the spanning line fragment with the given line fragments", ->
          map.insertAtBufferRow(0, [line0, line1, line2])
          map.spliceAtBufferRow(1, 1, [line3, line4])

          expect(map.bufferLineCount()).toBe 4
          expect(map.lineFragmentsForScreenRow(0)).toEqual [line0]
          expect(map.lineFragmentsForScreenRow(1)).toEqual [line3]
          expect(map.lineFragmentsForScreenRow(2)).toEqual [line4]
          expect(map.lineFragmentsForScreenRow(3)).toEqual [line2]

      describe "when the specified buffer row is spanned by multiple line fragments", ->
        it "replaces all spanning line fragments with the given line fragments", ->
          [line1a, line1b] = line1.splitAt(10)
          [line3a, line3b] = line3.splitAt(10)

          map.insertAtBufferRow(0, [line0, line1a, line1b, line2])
          map.spliceAtBufferRow(1, 1, [line3a, line3b, line4])

          expect(map.bufferLineCount()).toBe 4
          expect(map.lineFragmentsForScreenRow(0)).toEqual [line0]
          expect(map.lineFragmentsForScreenRow(1)).toEqual [line3a, line3b]
          expect(map.lineFragmentsForScreenRow(2)).toEqual [line4]
          expect(map.lineFragmentsForScreenRow(3)).toEqual [line2]

    describe "when called with a row count greater than 1", ->
      it "replaces all line fragments spanning the multiple buffer rows with the given line fragments", ->
        [line1a, line1b] = line1.splitAt(10)
        [line3a, line3b] = line3.splitAt(10)

        map.insertAtBufferRow(0, [line0, line1a, line1b, line2])
        map.spliceAtBufferRow(1, 2, [line3a, line3b, line4])

        expect(map.bufferLineCount()).toBe 3
        expect(map.lineFragmentsForScreenRow(0)).toEqual [line0]
        expect(map.lineFragmentsForScreenRow(1)).toEqual [line3a, line3b]
        expect(map.lineFragmentsForScreenRow(2)).toEqual [line4]

  describe ".lineFragmentsForScreenRows(startRow, endRow)", ->
    it "returns all line fragments for the given row range", ->
      [line1a, line1b] = line1.splitAt(10)
      [line3a, line3b] = line3.splitAt(10)
      map.insertAtBufferRow(0, [line0, line1a, line1b, line2, line3a, line3b, line4])

      expect(map.lineFragmentsForScreenRows(1, 3)).toEqual [line1a, line1b, line2, line3a, line3b]

  describe ".screenPositionFromBufferPosition(bufferPosition)", ->
    describe "", ->
      
    




