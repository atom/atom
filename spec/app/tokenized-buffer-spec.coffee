TokenizedBuffer = require 'tokenized-buffer'
LanguageMode = require 'language-mode'
Buffer = require 'buffer'
Range = require 'range'
_ = require 'underscore'

describe "TokenizedBuffer", ->
  [editSession, tokenizedBuffer, buffer] = []

  beforeEach ->
    editSession = fixturesProject.buildEditSessionForPath('sample.js', autoIndent: false)
    buffer = editSession.buffer
    tokenizedBuffer = editSession.displayBuffer.tokenizedBuffer

  afterEach ->
    editSession.destroy()

  describe ".findOpeningBracket(closingBufferPosition)", ->
    it "returns the position of the matching bracket, skipping any nested brackets", ->
      expect(tokenizedBuffer.findOpeningBracket([9, 2])).toEqual [1, 29]

  describe ".findClosingBracket(startBufferPosition)", ->
    it "returns the position of the matching bracket, skipping any nested brackets", ->
      expect(tokenizedBuffer.findClosingBracket([1, 29])).toEqual [9, 2]

  describe "tokenization", ->
    it "tokenizes all the lines in the buffer on construction", ->
      expect(tokenizedBuffer.lineForScreenRow(0).tokens[0]).toEqual(value: 'var', scopes: ['source.js', 'storage.modifier.js'])
      expect(tokenizedBuffer.lineForScreenRow(11).tokens[1]).toEqual(value: 'return', scopes: ['source.js', 'keyword.control.js'])

    describe "when the buffer changes", ->
      changeHandler = null

      beforeEach ->
        changeHandler = jasmine.createSpy('changeHandler')
        tokenizedBuffer.on "change", changeHandler

      describe "when lines are updated, but none are added or removed", ->
        it "updates tokens for each of the changed lines", ->
          range = new Range([0, 0], [2, 0])
          buffer.change(range, "foo()\n7\n")

          expect(tokenizedBuffer.lineForScreenRow(0).tokens[1]).toEqual(value: '(', scopes: ['source.js', 'meta.brace.round.js'])
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[0]).toEqual(value: '7', scopes: ['source.js', 'constant.numeric.js'])

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]

          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual new Range([0, 0], [2,0])

          # line 2 is unchanged
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[2]).toEqual(value: 'if', scopes: ['source.js', 'keyword.control.js'])

        it "updates tokens for lines beyond the changed lines if needed", ->
          buffer.insert([5, 30], '/* */')
          changeHandler.reset()

          buffer.insert([2, 0], '/*')
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
          expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(5).length])
          expect(event.newRange).toEqual new Range([2, 0], [5, buffer.lineForRow(5).length])

        it "resumes highlighting with the state of the previous line", ->
          buffer.insert([0, 0], '/*')
          buffer.insert([5, 0], '*/')

          buffer.insert([1, 0], 'var ')
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']

      describe "when lines are both updated and removed", ->
        it "updates tokens to reflect the removed lines", ->
          range = new Range([1, 0], [3, 0])
          buffer.change(range, "foo()")

          # previous line 0 remains
          expect(tokenizedBuffer.lineForScreenRow(0).tokens[0]).toEqual(value: 'var', scopes: ['source.js', 'storage.modifier.js'])

          # previous line 3 should be combined with input to form line 1
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[0]).toEqual(value: 'foo', scopes: ['source.js'])
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[6]).toEqual(value: '=', scopes: ['source.js', 'keyword.operator.js'])

          # lines below deleted regions should be shifted upward
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[2]).toEqual(value: 'while', scopes: ['source.js', 'keyword.control.js'])
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[4]).toEqual(value: '=', scopes: ['source.js', 'keyword.operator.js'])
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[4]).toEqual(value: '<', scopes: ['source.js', 'keyword.operator.js'])

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual new Range([1, 0], [1, 5])

        it "updates tokens for lines beyond the changed lines if needed", ->
          buffer.insert([5, 30], '/* */')
          changeHandler.reset()

          buffer.change(new Range([2, 0], [3, 0]), '/*')
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[0].scopes).toEqual ['source.js', 'comment.block.js', 'punctuation.definition.comment.js']
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(4).length])
          expect(event.newRange).toEqual new Range([2, 0], [4, buffer.lineForRow(4).length])

      describe "when lines are both updated and inserted", ->
        it "updates tokens to reflect the inserted lines", ->
          range = new Range([1, 0], [2, 0])
          buffer.change(range, "foo()\nbar()\nbaz()\nquux()")

          # previous line 0 remains
          expect(tokenizedBuffer.lineForScreenRow(0).tokens[0]).toEqual( value: 'var', scopes: ['source.js', 'storage.modifier.js'])

          # 3 new lines inserted
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[0]).toEqual(value: 'foo', scopes: ['source.js'])
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[0]).toEqual(value: 'bar', scopes: ['source.js'])
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[0]).toEqual(value: 'baz', scopes: ['source.js'])

          # previous line 2 is joined with quux() on line 4
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[0]).toEqual(value: 'quux', scopes: ['source.js'])
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[4]).toEqual(value: 'if', scopes: ['source.js', 'keyword.control.js'])

          # previous line 3 is pushed down to become line 5
          expect(tokenizedBuffer.lineForScreenRow(5).tokens[4]).toEqual(value: '=', scopes: ['source.js', 'keyword.operator.js'])

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual new Range([1, 0], [4, 6])

        it "updates tokens for lines beyond the changed lines if needed", ->
          buffer.insert([5, 30], '/* */')
          changeHandler.reset()

          buffer.insert([2, 0], '/*\nabcde\nabcder')
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[0].scopes).toEqual ['source.js', 'comment.block.js', 'punctuation.definition.comment.js']
          expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
          expect(tokenizedBuffer.lineForScreenRow(4).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
          expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
          expect(tokenizedBuffer.lineForScreenRow(6).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
          expect(tokenizedBuffer.lineForScreenRow(7).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
          expect(tokenizedBuffer.lineForScreenRow(8).tokens[0].scopes).not.toBe ['source.js', 'comment.block.js']

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(7).length])
          expect(event.newRange).toEqual new Range([2, 0], [7, buffer.lineForRow(7).length])

    describe "when the buffer contains tab characters", ->
      editSession2 = null

      beforeEach ->
        tabLength = 2
        editSession2 = fixturesProject.buildEditSessionForPath('sample-with-tabs.coffee', { tabLength })
        buffer = editSession2.buffer
        tokenizedBuffer = editSession2.displayBuffer.tokenizedBuffer

      afterEach ->
        editSession2.destroy()

      it "always renders each tab as its own atomic token with a value of size tabLength", ->
        tabAsSpaces = _.multiplyString(' ', editSession2.tabLength)
        screenLine0 = tokenizedBuffer.lineForScreenRow(0)
        expect(screenLine0.text).toBe "# Econ 101#{tabAsSpaces}"
        { tokens } = screenLine0

        expect(tokens.length).toBe 3
        expect(tokens[0].value).toBe "#"
        expect(tokens[1].value).toBe " Econ 101"
        expect(tokens[2].value).toBe tabAsSpaces
        expect(tokens[2].scopes).toEqual tokens[1].scopes
        expect(tokens[2].isAtomic).toBeTruthy()

        expect(tokenizedBuffer.lineForScreenRow(2).text).toBe "#{tabAsSpaces} buy()#{tabAsSpaces}while supply > demand"

  describe ".setTabLength(tabLength)", ->
    describe "when the file contains soft tabs", ->
      it "retokenizes leading whitespace based on the new tab length", ->
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].isAtomic).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].value).toBe "  "
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[1].isAtomic).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[1].value).toBe "  "

        tokenizedBuffer.setTabLength(4)
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].isAtomic).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].value).toBe "    "
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[1].isAtomic).toBeFalsy()
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[1].value).toBe "  current "
