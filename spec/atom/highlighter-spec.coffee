Highlighter = require 'highlighter'
Buffer = require 'buffer'
Range = require 'range'

describe "Highlighter", ->
  [highlighter, buffer] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    highlighter = new Highlighter(buffer)

  describe "constructor", ->
    it "tokenizes all the lines in the buffer", ->
      expect(highlighter.tokensForRow(0)[0]).toEqual(type: 'keyword.definition', value: 'var')
      expect(highlighter.tokensForRow(11)[1]).toEqual(type: 'keyword', value: 'return')

  describe "when the buffer changes", ->
    describe "when a single line is changed", ->
      it "updates tokens for the changed line", ->
        expect(highlighter.tokensForRow(0)[0]).toEqual(type: 'keyword.definition', value: 'var')
        buffer.change(new Range([0, 0], [0, 4]), '')
        expect(highlighter.tokensForRow(0)[0]).toEqual(type: 'identifier', value: 'quicksort')

      it "preserves the scanning state when tokenizing the changed line"
        # change the second line of a multi line comment and make sure it's still recognized as such

    describe "when multiple lines are updated, but none are added or removed", ->
      it "updates tokens for each of the changed lines", ->
        buffer.change(new Range([0, 0], [2, 0]), "foo()\nbar()\n")

        expect(highlighter.tokensForRow(0)[0]).toEqual(type: 'identifier', value: 'foo')
        expect(highlighter.tokensForRow(1)[0]).toEqual(type: 'identifier', value: 'bar')

        # line 2 is unchanged
        expect(highlighter.tokensForRow(2)[1]).toEqual(type: 'keyword', value: 'if')

    describe "when lines are both updated and removed", ->
      it "updates tokens to reflect the removed lines", ->
        buffer.change(new Range([1, 0], [3, 0]), "foo()")

        # previous line 0 remains
        expect(highlighter.tokensForRow(0)[0]).toEqual(type: 'keyword.definition', value: 'var')

        # previous line 3 should be combined with input to form line 1
        expect(highlighter.tokensForRow(1)[0]).toEqual(type: 'identifier', value: 'foo')
        expect(highlighter.tokensForRow(1)[6]).toEqual(type: 'identifier', value: 'pivot')

        # lines below deleted regions should be shifted upward
        expect(highlighter.tokensForRow(2)[1]).toEqual(type: 'keyword', value: 'while')
        expect(highlighter.tokensForRow(3)[1]).toEqual(type: 'identifier', value: 'current')
        expect(highlighter.tokensForRow(4)[3]).toEqual(type: 'keyword.operator', value: '<')

    describe "when lines are both updated and inserted", ->
      it "updates tokens to reflect the inserted lines", ->
        buffer.change(new Range([1, 0], [2, 0]), "foo()\nbar()\nbaz()\nquux()")

        # previous line 0 remains
        expect(highlighter.tokensForRow(0)[0]).toEqual(type: 'keyword.definition', value: 'var')

        # 3 new lines inserted
        expect(highlighter.tokensForRow(1)[0]).toEqual(type: 'identifier', value: 'foo')
        expect(highlighter.tokensForRow(2)[0]).toEqual(type: 'identifier', value: 'bar')
        expect(highlighter.tokensForRow(3)[0]).toEqual(type: 'identifier', value: 'baz')

        # previous line 2 is joined with quux() on line 4
        expect(highlighter.tokensForRow(4)[0]).toEqual(type: 'identifier', value: 'quux')
        expect(highlighter.tokensForRow(4)[4]).toEqual(type: 'keyword', value: 'if')

        # previous line 3 is pushed down to become line 5
        expect(highlighter.tokensForRow(5)[3]).toEqual(type: 'identifier', value: 'pivot')

