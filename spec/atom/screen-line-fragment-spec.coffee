_ = require 'underscore'
Buffer = require 'buffer'
Highlighter = require 'highlighter'

describe "screenLineFragment", ->
  lineFragment = null

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    highlighter = new Highlighter(buffer)
    lineFragment = highlighter.lineFragmentForRow(3)

  describe ".splitAt(column)", ->
    it "breaks the line fragment into two fragments", ->
      [left, right] = lineFragment.splitAt(31)
      expect(left.text).toBe '    var pivot = items.shift(), '
      expect(tokensText left.tokens).toBe left.text

      expect(right.text).toBe 'current, left = [], right = [];'
      expect(tokensText right.tokens).toBe right.text

    it "splits tokens if they straddle the split boundary", ->
      [left, right] = lineFragment.splitAt(34)
      expect(left.text).toBe '    var pivot = items.shift(), cur'
      expect(tokensText left.tokens).toBe left.text

      expect(right.text).toBe 'rent, left = [], right = [];'
      expect(tokensText right.tokens).toBe right.text

      expect(_.last(left.tokens).type).toBe right.tokens[0].type

    it "ensures the returned fragments cover the span of the original line", ->
      [left, right] = lineFragment.splitAt(15)
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
      it "returns undefined for the left half", ->
        expect(lineFragment.splitAt(0)).toEqual [undefined, lineFragment]

    describe "if splitting at a column >= the line length", ->
      it "returns undefined for the right half", ->
        expect(lineFragment.splitAt(lineFragment.text.length)).toEqual [lineFragment, undefined]
