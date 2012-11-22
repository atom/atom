TokenizedBuffer = require 'tokenized-buffer'
LanguageMode = require 'language-mode'
Buffer = require 'buffer'
Range = require 'range'
_ = require 'underscore'

fdescribe "TokenizedBuffer", ->
  [editSession, tokenizedBuffer, buffer, changeHandler] = []

  beforeEach ->
    # enable async tokenization
    TokenizedBuffer.prototype.chunkSize = 5
    jasmine.unspy(TokenizedBuffer.prototype, 'tokenizeInBackground')

  fullyTokenize = (tokenizedBuffer) ->
    advanceClock() while tokenizedBuffer.firstInvalidRow()?
    changeHandler.reset()

  describe "when the buffer contains soft-tabs", ->
    beforeEach ->
      editSession = fixturesProject.buildEditSessionForPath('sample.js', autoIndent: false)
      buffer = editSession.buffer
      tokenizedBuffer = editSession.displayBuffer.tokenizedBuffer
      changeHandler = jasmine.createSpy('changeHandler')
      tokenizedBuffer.on "change", changeHandler

    afterEach ->
      editSession.destroy()

    describe "on construction", ->
      it "initially creates un-tokenized screen lines, then tokenizes lines chunk at a time in the background", ->
        line0 = tokenizedBuffer.lineForScreenRow(0)
        expect(line0.tokens.length).toBe 1
        expect(line0.tokens[0]).toEqual(value: line0.text, scopes: ['source.js'])

        line11 = tokenizedBuffer.lineForScreenRow(11)
        expect(line11.tokens.length).toBe 2
        expect(line11.tokens[0]).toEqual(value: "  ", scopes: ['source.js'], isAtomic: true)
        expect(line11.tokens[1]).toEqual(value: "return sort(Array.apply(this, arguments));", scopes: ['source.js'])

        # background tokenization has not begun
        expect(tokenizedBuffer.lineForScreenRow(0).ruleStack).toBeUndefined()

        # tokenize chunk 1
        advanceClock()
        expect(tokenizedBuffer.lineForScreenRow(0).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(4).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(5).ruleStack?).toBeFalsy()
        expect(changeHandler).toHaveBeenCalledWith(start: 0, end: 4, delta: 0)
        changeHandler.reset()

        # tokenize chunk 2
        advanceClock()
        expect(tokenizedBuffer.lineForScreenRow(5).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(9).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(10).ruleStack?).toBeFalsy()
        expect(changeHandler).toHaveBeenCalledWith(start: 5, end: 9, delta: 0)
        changeHandler.reset()

        # tokenize last chunk
        advanceClock()
        expect(tokenizedBuffer.lineForScreenRow(10).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(12).ruleStack?).toBeTruthy()
        expect(changeHandler).toHaveBeenCalledWith(start: 10, end: 12, delta: 0)

    describe "when the buffer is partially tokenized", ->
      beforeEach ->
        # tokenize chunk 1 only
        advanceClock()

      describe "when there is a buffer change inside a tokenized region", ->

      describe "when there is a buffer change surrounding an invalid row", ->

      describe "when there is a buffer change inside an invalid region", ->

    describe "when the buffer is fully tokenized", ->
      beforeEach ->
        fullyTokenize(tokenizedBuffer)

      describe "when there is a buffer change that is smaller than the chunk size", ->
        describe "when lines are updated, but none are added or removed", ->
          it "updates tokens to reflect the change", ->
            buffer.change([[0, 0], [2, 0]], "foo()\n7\n")

            expect(tokenizedBuffer.lineForScreenRow(0).tokens[1]).toEqual(value: '(', scopes: ['source.js', 'meta.brace.round.js'])
            expect(tokenizedBuffer.lineForScreenRow(1).tokens[0]).toEqual(value: '7', scopes: ['source.js', 'constant.numeric.js'])
            # line 2 is unchanged
            expect(tokenizedBuffer.lineForScreenRow(2).tokens[2]).toEqual(value: 'if', scopes: ['source.js', 'keyword.control.js'])

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 0, end: 2, delta: 0)

          describe "when the change invalidates the tokenization of subsequent lines", ->
            it "schedules the invalidated lines to be tokenized in the background", ->
              buffer.insert([5, 30], '/* */')
              changeHandler.reset()
              buffer.insert([2, 0], '/*')
              expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].scopes).toEqual ['source.js']
              expect(changeHandler).toHaveBeenCalled()
              [event] = changeHandler.argsForCall[0]
              delete event.bufferChange
              expect(event).toEqual(start: 2, end: 2, delta: 0)
              changeHandler.reset()

              advanceClock()
              expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
              expect(tokenizedBuffer.lineForScreenRow(4).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
              expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
              expect(changeHandler).toHaveBeenCalled()
              [event] = changeHandler.argsForCall[0]
              delete event.bufferChange
              expect(event).toEqual(start: 3, end: 5, delta: 0)

          it "resumes highlighting with the state of the previous line", ->
            buffer.insert([0, 0], '/*')
            buffer.insert([5, 0], '*/')

            buffer.insert([1, 0], 'var ')
            expect(tokenizedBuffer.lineForScreenRow(1).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']

        describe "when lines are both updated and removed", ->
          it "updates tokens to reflect the change", ->
            buffer.change([[1, 0], [3, 0]], "foo()")

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
            delete event.bufferChange
            expect(event).toEqual(start: 1, end: 3, delta: -2)

        describe "when the change invalidates the tokenization of subsequent lines", ->
          it "schedules the invalidated lines to be tokenized in the background", ->
            buffer.insert([5, 30], '/* */')
            changeHandler.reset()

            buffer.change([[2, 0], [3, 0]], '/*')
            expect(tokenizedBuffer.lineForScreenRow(2).tokens[0].scopes).toEqual ['source.js', 'comment.block.js', 'punctuation.definition.comment.js']
            expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].scopes).toEqual ['source.js']
            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 2, end: 3, delta: -1)
            changeHandler.reset()

            advanceClock()
            expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.lineForScreenRow(4).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 3, end: 4, delta: 0)

        describe "when lines are both updated and inserted", ->
          it "updates tokens to reflect the change", ->
            buffer.change([[1, 0], [2, 0]], "foo()\nbar()\nbaz()\nquux()")

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
            delete event.bufferChange
            expect(event).toEqual(start: 1, end: 2, delta: 2)

        describe "when the change invalidates the tokenization of subsequent lines", ->
          it "schedules the invalidated lines to be tokenized in the background", ->
            buffer.insert([5, 30], '/* */')
            changeHandler.reset()

            buffer.insert([2, 0], '/*\nabcde\nabcder')
            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 2, end: 2, delta: 2)
            expect(tokenizedBuffer.lineForScreenRow(2).tokens[0].scopes).toEqual ['source.js', 'comment.block.js', 'punctuation.definition.comment.js']
            expect(tokenizedBuffer.lineForScreenRow(3).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.lineForScreenRow(4).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].scopes).toEqual ['source.js']
            changeHandler.reset()

            advanceClock() # tokenize invalidated lines in background
            expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.lineForScreenRow(6).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.lineForScreenRow(7).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.lineForScreenRow(8).tokens[0].scopes).not.toBe ['source.js', 'comment.block.js']

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 5, end: 7, delta: 0)

      describe ".findOpeningBracket(closingBufferPosition)", ->
        it "returns the position of the matching bracket, skipping any nested brackets", ->
          expect(tokenizedBuffer.findOpeningBracket([9, 2])).toEqual [1, 29]

      describe ".findClosingBracket(startBufferPosition)", ->
        it "returns the position of the matching bracket, skipping any nested brackets", ->
          expect(tokenizedBuffer.findClosingBracket([1, 29])).toEqual [9, 2]

      it "tokenizes leading whitespace based on the new tab length", ->
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].isAtomic).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].value).toBe "  "
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[1].isAtomic).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[1].value).toBe "  "

        tokenizedBuffer.setTabLength(4)
        fullyTokenize(tokenizedBuffer)

        expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].isAtomic).toBeTruthy()
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[0].value).toBe "    "
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[1].isAtomic).toBeFalsy()
        expect(tokenizedBuffer.lineForScreenRow(5).tokens[1].value).toBe "  current "

  describe "when the buffer contains hard-tabs", ->
    beforeEach ->
      tabLength = 2
      editSession = fixturesProject.buildEditSessionForPath('sample-with-tabs.coffee', { tabLength })
      buffer = editSession.buffer
      tokenizedBuffer = editSession.displayBuffer.tokenizedBuffer

    afterEach ->
      editSession.destroy()

    describe "when the buffer is fully tokenized", ->
      beforeEach ->
        fullyTokenize(tokenizedBuffer)

      it "renders each tab as its own atomic token with a value of size tabLength", ->
        tabAsSpaces = _.multiplyString(' ', editSession.getTabLength())
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

