_ = require 'underscore'
Buffer = require 'buffer'
TokenizedBuffer = require 'tokenized-buffer'

describe "ScreenLine", ->
  [buffer, tabText, screenLine, tokenizedBuffer] = []

  beforeEach ->
    tabText = '  '
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    tokenizedBuffer = new TokenizedBuffer(buffer, tabText)
    screenLine = tokenizedBuffer.lineForScreenRow(3)

  afterEach ->
    buffer.destroy()

  describe ".splitAt(column)", ->
    it "breaks the line fragment into two fragments", ->
      [left, right] = screenLine.splitAt(31)
      expect(left.text).toBe '    var pivot = items.shift(), '
      expect(tokensText left.tokens).toBe left.text

      expect(right.text).toBe 'current, left = [], right = [];'
      expect(tokensText right.tokens).toBe right.text

    it "splits tokens if they straddle the split boundary", ->
      [left, right] = screenLine.splitAt(34)
      expect(left.text).toBe '    var pivot = items.shift(), cur'
      expect(tokensText left.tokens).toBe left.text

      expect(right.text).toBe 'rent, left = [], right = [];'
      expect(tokensText right.tokens).toBe right.text

      expect(_.last(left.tokens).type).toBe right.tokens[0].type

    it "ensures the returned fragments cover the span of the original line", ->
      [left, right] = screenLine.splitAt(15)
      expect(left.bufferDelta).toEqual [0, 15]
      expect(left.screenDelta).toEqual [0, 15]

      expect(right.bufferDelta).toEqual [1, 0]
      expect(right.screenDelta).toEqual [1, 0]

      [left2, right2] = left.splitAt(5)
      expect(left2.bufferDelta).toEqual [0, 5]
      expect(left2.screenDelta).toEqual [0, 5]

      expect(right2.bufferDelta).toEqual [0, 10]
      expect(right2.screenDelta).toEqual [0, 10]

    describe "if splitting at 0", ->
      it "returns an empty line fragment for the left half", ->
        left = screenLine.splitAt(0)[0]
        expect(left.text).toBe ''
        expect(left.tokens).toEqual []
        expect(left.bufferDelta).toEqual [0, 0]
        expect(left.screenDelta).toEqual [0, 0]

    describe "if splitting at a column equal to the line length", ->
      it "returns an empty line fragment that spans a row for the right half", ->
        [left, right] = screenLine.splitAt(screenLine.text.length)

        expect(left.text).toBe screenLine.text
        expect(left.screenDelta).toEqual [0, screenLine.text.length]
        expect(left.bufferDelta).toEqual [0, screenLine.text.length]

        expect(right.text).toBe ''
        expect(right.screenDelta).toEqual [1, 0]
        expect(right.bufferDelta).toEqual [1, 0]

  describe ".concat(otherFragment)", ->
    it "returns the concatenation of the receiver and the given fragment", ->
      [left, right] = screenLine.splitAt(14)
      expect(left.concat(right)).toEqual screenLine

      concatenated = screenLine.concat(tokenizedBuffer.lineForScreenRow(4))
      expect(concatenated.text).toBe '    var pivot = items.shift(), current, left = [], right = [];    while(items.length > 0) {'
      expect(tokensText concatenated.tokens).toBe concatenated.text
      expect(concatenated.screenDelta).toEqual [2, 0]
      expect(concatenated.bufferDelta).toEqual [2, 0]

  describe ".translateColumn(sourceDeltaType, targetDeltaType, sourceColumn, skipAtomicTokens: false)", ->
    beforeEach ->
      buffer.insert([0, 13], '\t')
      buffer.insert([0, 0], '\t\t')
      screenLine = tokenizedBuffer.lineForScreenRow(0)

    describe "when translating from buffer to screen coordinates", ->
      it "accounts for tab characters being wider on screen", ->
        expect(screenLine.translateColumn('bufferDelta', 'screenDelta', 0)).toBe 0
        expect(screenLine.translateColumn('bufferDelta', 'screenDelta', 1)).toBe 2
        expect(screenLine.translateColumn('bufferDelta', 'screenDelta', 2)).toBe 4
        expect(screenLine.translateColumn('bufferDelta', 'screenDelta', 3)).toBe 5
        expect(screenLine.translateColumn('bufferDelta', 'screenDelta', 15)).toBe 17
        expect(screenLine.translateColumn('bufferDelta', 'screenDelta', 16)).toBe 19

    describe "when translating from screen coordinates to buffer coordinates", ->
      describe "when skipAtomicTokens is false (the default)", ->
        it "clips positions in the middle of tab tokens to the beginning", ->
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 0)).toBe 0
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 1)).toBe 0
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 2)).toBe 1
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 3)).toBe 1
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 4)).toBe 2
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 5)).toBe 3

      describe "when skipAtomicTokens is true", ->
        it "clips positions in the middle of tab tokens to the end", ->
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 0, skipAtomicTokens: true)).toBe 0
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 1, skipAtomicTokens: true)).toBe 1
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 2, skipAtomicTokens: true)).toBe 1
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 3, skipAtomicTokens: true)).toBe 2
          expect(screenLine.translateColumn('screenDelta', 'bufferDelta', 5, skipAtomicTokens: true)).toBe 3

