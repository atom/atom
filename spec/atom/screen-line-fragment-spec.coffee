_ = require 'underscore'
Buffer = require 'buffer'
Highlighter = require 'highlighter'

describe "screenLineFragment", ->
  [screenLine, highlighter] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    highlighter = new Highlighter(buffer)
    screenLine = highlighter.lineForScreenRow(3)

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
      expect(left.inputDelta).toEqual [0, 15]
      expect(left.outputDelta).toEqual [0, 15]

      expect(right.inputDelta).toEqual [1, 0]
      expect(right.outputDelta).toEqual [1, 0]

      [left2, right2] = left.splitAt(5)
      expect(left2.inputDelta).toEqual [0, 5]
      expect(left2.outputDelta).toEqual [0, 5]

      expect(right2.inputDelta).toEqual [0, 10]
      expect(right2.outputDelta).toEqual [0, 10]

    describe "if splitting at 0", ->
      it "returns an empty line fragment for the left half", ->
        left = screenLine.splitAt(0)[0]
        expect(left.text).toBe ''
        expect(left.tokens).toEqual []
        expect(left.inputDelta).toEqual [0, 0]
        expect(left.outputDelta).toEqual [0, 0]

    describe "if splitting at a column equal to the line length", ->
      it "returns an empty line fragment that spans a row for the right half", ->
        [left, right] = screenLine.splitAt(screenLine.text.length)

        expect(left.text).toBe screenLine.text
        expect(left.outputDelta).toEqual [0, screenLine.text.length]
        expect(left.inputDelta).toEqual [0, screenLine.text.length]

        expect(right.text).toBe ''
        expect(right.outputDelta).toEqual [1, 0]
        expect(right.inputDelta).toEqual [1, 0]

  describe ".concat(otherFragment)", ->
    it "returns the concatenation of the receiver and the given fragment", ->
      [left, right] = screenLine.splitAt(14)
      expect(left.concat(right)).toEqual screenLine

      concatenated = screenLine.concat(highlighter.lineForScreenRow(4))
      expect(concatenated.text).toBe '    var pivot = items.shift(), current, left = [], right = [];    while(items.length > 0) {'
      expect(tokensText concatenated.tokens).toBe concatenated.text
      expect(concatenated.outputDelta).toEqual [2, 0]
      expect(concatenated.inputDelta).toEqual [2, 0]





