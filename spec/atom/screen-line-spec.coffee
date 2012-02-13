Buffer = require 'buffer'
Highlighter = require 'highlighter'

describe "ScreenLine", ->
  screenLine = null

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    highlighter = new Highlighter(buffer)
    screenLine = highlighter.screenLineForRow(3)

  describe ".splitAt(splitColumn)", ->
    describe "when the split column is less than the line length", ->
      describe "when the split column is at the start of a token", ->
        it "returns two screen lines", ->
          [left, right] = screenLine.splitAt(31)
          expect(left.text).toBe '    var pivot = items.shift(), '
          expect(tokensText left.tokens).toBe left.text

          expect(right.text).toBe 'current, left = [], right = [];'
          expect(tokensText right.tokens).toBe right.text

      describe "when the split column is in the middle of a token", ->
        it "it returns two screen lines, with the token split in half", ->
          [left, right] = screenLine.splitAt(34)
          expect(left.text).toBe '    var pivot = items.shift(), cur'
          expect(tokensText left.tokens).toBe left.text

          expect(right.text).toBe 'rent, left = [], right = [];'
          expect(tokensText right.tokens).toBe right.text

    describe "when the split column is 0 or equals the line length", ->
      it "returns a singleton array of the screen line (doesn't split it)", ->
        expect(screenLine.splitAt(0)).toEqual([screenLine])
        expect(screenLine.splitAt(screenLine.text.length)).toEqual([screenLine])

