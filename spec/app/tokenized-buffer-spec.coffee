TokenizedBuffer = require 'tokenized-buffer'
LanguageMode = require 'language-mode'
Buffer = require 'buffer'
Range = require 'range'

describe "TokenizedBuffer", ->
  [editSession, tokenizedBuffer, buffer] = []

  beforeEach ->
    editSession = fixturesProject.buildEditSessionForPath('sample.js', autoIndent: false)
    { tokenizedBuffer, buffer } = editSession

  afterEach ->
    editSession.destroy()

  describe ".findClosingBracket(startBufferPosition)", ->
    it "returns the position of the matching bracket, skipping any nested brackets", ->
      expect(tokenizedBuffer.findClosingBracket([1, 29])).toEqual [9, 2]

  describe ".findOpeningBracket(closingBufferPosition)", ->
    it "returns the position of the matching bracket, skipping any nested brackets", ->
      expect(tokenizedBuffer.findOpeningBracket([9, 2])).toEqual [1, 29]

  describe "tokenization", ->
    it "tokenizes all the lines in the buffer on construction", ->
      expect(tokenizedBuffer.lineForScreenRow(0).tokens[0]).toEqual(value: 'var', scopes: ['source.js', 'storage.type.js'])
      expect(tokenizedBuffer.lineForScreenRow(11).tokens[1]).toEqual(value: 'return', scopes: ['source.js', 'keyword.control.js'])

    describe "when the buffer changes", ->
      changeHandler = null

      beforeEach ->
        changeHandler = jasmine.createSpy('changeHandler')
        tokenizedBuffer.on "change", changeHandler

      describe "when lines are updated, but none are added or removed", ->
        fit "updates tokens for each of the changed lines", ->
          range = new Range([0, 0], [2, 0])
          buffer.change(range, "foo()\n7\n")

          expect(tokenizedBuffer.lineForScreenRow(0).tokens[1]).toEqual(value: '(', scopes: ['source.js', 'meta.brace.round.js'])
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[0]).toEqual(value: '7', scopes: ['source.js', 'constant.numeric.js'])

          # line 2 is unchanged
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[1]).toEqual(value: 'if', scopes: ['source.js'])

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]

          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual new Range([0, 0], [2,0])

        it "updates tokens for lines beyond the changed lines if needed", ->
          buffer.insert([5, 30], '/* */')
          changeHandler.reset()

          buffer.insert([2, 0], '/*')
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].type).toBe 'comment'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(5).length])
          expect(event.newRange).toEqual new Range([2, 0], [5, buffer.lineForRow(5).length])

        it "resumes highlighting with the state of the previous line", ->
          buffer.insert([0, 0], '/*')
          buffer.insert([5, 0], '*/')

          buffer.insert([1, 0], 'var ')
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[0].type).toBe 'comment'

      describe "when lines are both updated and removed", ->
        it "updates tokens to reflect the removed lines", ->
          range = new Range([1, 0], [3, 0])
          buffer.change(range, "foo()")

          # previous line 0 remains
          expect(tokenizedBuffer.lineForScreenRow(0).tokens[0]).toEqual(type: 'keyword.definition', value: 'var')

          # previous line 3 should be combined with input to form line 1
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[0]).toEqual(type: 'identifier', value: 'foo')
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[6]).toEqual(type: 'identifier', value: 'pivot')

          # lines below deleted regions should be shifted upward
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[1]).toEqual(type: 'keyword', value: 'while')
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[1]).toEqual(type: 'identifier', value: 'current')
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[3]).toEqual(type: 'keyword.operator', value: '<')

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual new Range([1, 0], [1, 5])

        it "updates tokens for lines beyond the changed lines if needed", ->
          buffer.insert([5, 30], '/* */')
          changeHandler.reset()

          buffer.change(new Range([2, 0], [3, 0]), '/*')
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[0].type).toBe 'comment'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(4).length])
          expect(event.newRange).toEqual new Range([2, 0], [4, buffer.lineForRow(4).length])

      describe "when lines are both updated and inserted", ->
        it "updates tokens to reflect the inserted lines", ->
          range = new Range([1, 0], [2, 0])
          buffer.change(range, "foo()\nbar()\nbaz()\nquux()")

          # previous line 0 remains
          expect(tokenizedBuffer.lineForScreenRow(0).tokens[0]).toEqual(type: 'keyword.definition', value: 'var')

          # 3 new lines inserted
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[0]).toEqual(type: 'identifier', value: 'foo')
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[0]).toEqual(type: 'identifier', value: 'bar')
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[0]).toEqual(type: 'identifier', value: 'baz')

          # previous line 2 is joined with quux() on line 4
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[0]).toEqual(type: 'identifier', value: 'quux')
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[4]).toEqual(type: 'keyword', value: 'if')

          # previous line 3 is pushed down to become line 5
          expect(tokenizedBuffer.lineForScreenRow(5).tokens[3]).toEqual(type: 'identifier', value: 'pivot')

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual new Range([1, 0], [4, 6])

        it "updates tokens for lines beyond the changed lines if needed", ->
          buffer.insert([5, 30], '/* */')
          changeHandler.reset()

          buffer.insert([2, 0], '/*\nabcde\nabcder')
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(6).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(7).tokens[0].type).toBe 'comment'
          expect(tokenizedBuffer.lineForScreenRow(8).tokens[0].type).not.toBe 'comment'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(7).length])
          expect(event.newRange).toEqual new Range([2, 0], [7, buffer.lineForRow(7).length])

    describe "when the buffer contains tab characters", ->
      tabText = '  '
      editSession2 = null

      beforeEach ->
        editSession2 = fixturesProject.buildEditSessionForPath('sample-with-tabs.coffee', { tabText })
        { buffer, tokenizedBuffer } = editSession2

      afterEach ->
        editSession2.destroy()

      it "always renders each tab as its own atomic token containing tabText", ->
        screenLine0 = tokenizedBuffer.lineForScreenRow(0)
        expect(screenLine0.text).toBe "# Econ 101#{tabText}"
        { tokens } = screenLine0
        expect(tokens.length).toBe 2
        expect(tokens[0].value).toBe "# Econ 101"
        expect(tokens[1].value).toBe tabText
        expect(tokens[1].type).toBe tokens[0].type
        expect(tokens[1].isAtomic).toBeTruthy()

        expect(tokenizedBuffer.lineForScreenRow(2).text).toBe "#{tabText} buy()#{tabText}while supply > demand"
