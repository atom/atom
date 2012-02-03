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
    changeHandler = null

    beforeEach ->
      changeHandler = jasmine.createSpy('changeHandler')
      highlighter.on "change", changeHandler

    describe "when lines are updated, but none are added or removed", ->
      it "updates tokens for each of the changed lines", ->
        range = new Range([0, 0], [2, 0])
        buffer.change(range, "foo()\nbar()\n")

        expect(highlighter.tokensForRow(0)[0]).toEqual(type: 'identifier', value: 'foo')
        expect(highlighter.tokensForRow(1)[0]).toEqual(type: 'identifier', value: 'bar')

        # line 2 is unchanged
        expect(highlighter.tokensForRow(2)[1]).toEqual(type: 'keyword', value: 'if')

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]

        expect(event.preRange).toEqual range
        expect(event.postRange).toEqual new Range([0, 0], [2,0])

      it "updates tokens for lines beyond the changed lines if needed", ->
        buffer.insert([5, 30], '/* */')
        changeHandler.reset()

        buffer.insert([2, 0], '/*')
        expect(highlighter.tokensForRow(3)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(4)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(5)[0].type).toBe 'comment'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.preRange).toEqual new Range([2, 0], [6, buffer.getLine(6).length])
        expect(event.postRange).toEqual new Range([2, 0], [6, buffer.getLine(6).length])

    describe "when lines are both updated and removed", ->
      it "updates tokens to reflect the removed lines", ->
        range = new Range([1, 0], [3, 0])
        buffer.change(range, "foo()")

        # previous line 0 remains
        expect(highlighter.tokensForRow(0)[0]).toEqual(type: 'keyword.definition', value: 'var')

        # previous line 3 should be combined with input to form line 1
        expect(highlighter.tokensForRow(1)[0]).toEqual(type: 'identifier', value: 'foo')
        expect(highlighter.tokensForRow(1)[6]).toEqual(type: 'identifier', value: 'pivot')

        # lines below deleted regions should be shifted upward
        expect(highlighter.tokensForRow(2)[1]).toEqual(type: 'keyword', value: 'while')
        expect(highlighter.tokensForRow(3)[1]).toEqual(type: 'identifier', value: 'current')
        expect(highlighter.tokensForRow(4)[3]).toEqual(type: 'keyword.operator', value: '<')

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.preRange).toEqual range
        expect(event.postRange).toEqual new Range([1, 0], [1, 5])

      it "updates tokens for lines beyond the changed lines if needed", ->
        buffer.insert([5, 30], '/* */')
        changeHandler.reset()

        buffer.change(new Range([2, 0], [3, 0]), '/*')
        expect(highlighter.tokensForRow(2)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(3)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(4)[0].type).toBe 'comment'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.preRange).toEqual new Range([2, 0], [6, buffer.getLine(5).length])
        expect(event.postRange).toEqual new Range([2, 0], [5, buffer.getLine(5).length])

    describe "when lines are both updated and inserted", ->
      it "updates tokens to reflect the inserted lines", ->
        range = new Range([1, 0], [2, 0])
        buffer.change(range, "foo()\nbar()\nbaz()\nquux()")

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

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.preRange).toEqual range
        expect(event.postRange).toEqual new Range([1, 0], [4, 6])

      it "updates tokens for lines beyond the changed lines if needed", ->
        buffer.insert([5, 30], '/* */')
        changeHandler.reset()

        buffer.insert([2, 0], '/*\nabcde\nabcder')
        expect(highlighter.tokensForRow(2)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(3)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(4)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(5)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(6)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(7)[0].type).toBe 'comment'
        expect(highlighter.tokensForRow(8)[0].type).not.toBe 'comment'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.preRange).toEqual new Range([2, 0], [6, buffer.getLine(8).length])
        expect(event.postRange).toEqual new Range([2, 0], [8, buffer.getLine(8).length])
