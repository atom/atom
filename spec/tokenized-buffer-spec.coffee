TokenizedBuffer = require '../src/tokenized-buffer'
TextBuffer = require 'text-buffer'
_ = require 'underscore-plus'

describe "TokenizedBuffer", ->
  [tokenizedBuffer, buffer, changeHandler] = []

  beforeEach ->
    # enable async tokenization
    TokenizedBuffer.prototype.chunkSize = 5
    jasmine.unspy(TokenizedBuffer.prototype, 'tokenizeInBackground')

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

  afterEach ->
    tokenizedBuffer?.destroy()

  startTokenizing = (tokenizedBuffer) ->
    tokenizedBuffer.setVisible(true)

  fullyTokenize = (tokenizedBuffer) ->
    tokenizedBuffer.setVisible(true)
    advanceClock() while tokenizedBuffer.firstInvalidRow()?
    changeHandler?.reset()

  describe "when the buffer is destroyed", ->
    beforeEach ->
      buffer = atom.project.bufferForPathSync('sample.js')
      tokenizedBuffer = new TokenizedBuffer({buffer})
      startTokenizing(tokenizedBuffer)

    it "stops tokenization", ->
      tokenizedBuffer.destroy()
      spyOn(tokenizedBuffer, 'tokenizeNextChunk')
      advanceClock()
      expect(tokenizedBuffer.tokenizeNextChunk).not.toHaveBeenCalled()

  describe "when the buffer contains soft-tabs", ->
    beforeEach ->
      buffer = atom.project.bufferForPathSync('sample.js')
      tokenizedBuffer = new TokenizedBuffer({buffer})
      startTokenizing(tokenizedBuffer)
      tokenizedBuffer.onDidChange changeHandler = jasmine.createSpy('changeHandler')

    afterEach ->
      tokenizedBuffer.destroy()
      buffer.release()

    describe "on construction", ->
      it "initially creates un-tokenized screen lines, then tokenizes lines chunk at a time in the background", ->
        line0 = tokenizedBuffer.tokenizedLineForRow(0)
        expect(line0.tokens.length).toBe 1
        expect(line0.tokens[0]).toEqual(value: line0.text, scopes: ['source.js'])

        line11 = tokenizedBuffer.tokenizedLineForRow(11)
        expect(line11.tokens.length).toBe 2
        expect(line11.tokens[0]).toEqual(value: "  ", scopes: ['source.js'], isAtomic: true)
        expect(line11.tokens[1]).toEqual(value: "return sort(Array.apply(this, arguments));", scopes: ['source.js'])

        # background tokenization has not begun
        expect(tokenizedBuffer.tokenizedLineForRow(0).ruleStack).toBeUndefined()

        # tokenize chunk 1
        advanceClock()
        expect(tokenizedBuffer.tokenizedLineForRow(0).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.tokenizedLineForRow(4).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.tokenizedLineForRow(5).ruleStack?).toBeFalsy()
        expect(changeHandler).toHaveBeenCalledWith(start: 0, end: 4, delta: 0)
        changeHandler.reset()

        # tokenize chunk 2
        advanceClock()
        expect(tokenizedBuffer.tokenizedLineForRow(5).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.tokenizedLineForRow(9).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.tokenizedLineForRow(10).ruleStack?).toBeFalsy()
        expect(changeHandler).toHaveBeenCalledWith(start: 5, end: 9, delta: 0)
        changeHandler.reset()

        # tokenize last chunk
        advanceClock()
        expect(tokenizedBuffer.tokenizedLineForRow(10).ruleStack?).toBeTruthy()
        expect(tokenizedBuffer.tokenizedLineForRow(12).ruleStack?).toBeTruthy()
        expect(changeHandler).toHaveBeenCalledWith(start: 10, end: 12, delta: 0)

    describe "when the buffer is partially tokenized", ->
      beforeEach ->
        # tokenize chunk 1 only
        advanceClock()
        changeHandler.reset()

      describe "when there is a buffer change inside the tokenized region", ->
        describe "when lines are added", ->
          it "pushes the invalid rows down", ->
            expect(tokenizedBuffer.firstInvalidRow()).toBe 5
            buffer.insert([1, 0], '\n\n')
            changeHandler.reset()

            expect(tokenizedBuffer.firstInvalidRow()).toBe 7
            advanceClock()
            expect(changeHandler).toHaveBeenCalledWith(start: 7, end: 11, delta: 0)

        describe "when lines are removed", ->
          it "pulls the invalid rows up", ->
            expect(tokenizedBuffer.firstInvalidRow()).toBe 5
            buffer.delete([[1, 0], [3, 0]])
            changeHandler.reset()

            expect(tokenizedBuffer.firstInvalidRow()).toBe 3
            advanceClock()
            expect(changeHandler).toHaveBeenCalledWith(start: 3, end: 7, delta: 0)

        describe "when the change invalidates all the lines before the current invalid region", ->
          it "retokenizes the invalidated lines and continues into the valid region", ->
            expect(tokenizedBuffer.firstInvalidRow()).toBe 5
            buffer.insert([2, 0], '/*')
            changeHandler.reset()
            expect(tokenizedBuffer.firstInvalidRow()).toBe 3

            advanceClock()
             # we discover that row 2 starts a foldable region when line 3 gets tokenized
            expect(changeHandler).toHaveBeenCalledWith(start: 2, end: 7, delta: 0)
            expect(tokenizedBuffer.firstInvalidRow()).toBe 8

      describe "when there is a buffer change surrounding an invalid row", ->
        it "pushes the invalid row to the end of the change", ->
          buffer.setTextInRange([[4, 0], [6, 0]], "\n\n\n")
          changeHandler.reset()

          expect(tokenizedBuffer.firstInvalidRow()).toBe 8
          advanceClock()

      describe "when there is a buffer change inside an invalid region", ->
        it "does not attempt to tokenize the lines in the change, and preserves the existing invalid row", ->
          expect(tokenizedBuffer.firstInvalidRow()).toBe 5
          buffer.setTextInRange([[6, 0], [7, 0]], "\n\n\n")

          expect(tokenizedBuffer.tokenizedLineForRow(6).ruleStack?).toBeFalsy()
          expect(tokenizedBuffer.tokenizedLineForRow(7).ruleStack?).toBeFalsy()

          changeHandler.reset()
          expect(tokenizedBuffer.firstInvalidRow()).toBe 5

    describe "when the buffer is fully tokenized", ->
      beforeEach ->
        fullyTokenize(tokenizedBuffer)

      describe "when there is a buffer change that is smaller than the chunk size", ->
        describe "when lines are updated, but none are added or removed", ->
          it "updates tokens to reflect the change", ->
            buffer.setTextInRange([[0, 0], [2, 0]], "foo()\n7\n")

            expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[1]).toEqual(value: '(', scopes: ['source.js', 'meta.brace.round.js'])
            expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[0]).toEqual(value: '7', scopes: ['source.js', 'constant.numeric.js'])
            # line 2 is unchanged
            expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[2]).toEqual(value: 'if', scopes: ['source.js', 'keyword.control.js'])

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 0, end: 2, delta: 0)

          describe "when the change invalidates the tokenization of subsequent lines", ->
            it "schedules the invalidated lines to be tokenized in the background", ->
              buffer.insert([5, 30], '/* */')
              changeHandler.reset()
              buffer.insert([2, 0], '/*')
              expect(tokenizedBuffer.tokenizedLineForRow(3).tokens[0].scopes).toEqual ['source.js']
              expect(changeHandler).toHaveBeenCalled()
              [event] = changeHandler.argsForCall[0]
              delete event.bufferChange
              expect(event).toEqual(start: 1, end: 2, delta: 0)
              changeHandler.reset()

              advanceClock()
              expect(tokenizedBuffer.tokenizedLineForRow(3).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
              expect(tokenizedBuffer.tokenizedLineForRow(4).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
              expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
              expect(changeHandler).toHaveBeenCalled()
              [event] = changeHandler.argsForCall[0]
              delete event.bufferChange
               # we discover that row 2 starts a foldable region when line 3 gets tokenized
              expect(event).toEqual(start: 2, end: 5, delta: 0)

          it "resumes highlighting with the state of the previous line", ->
            buffer.insert([0, 0], '/*')
            buffer.insert([5, 0], '*/')

            buffer.insert([1, 0], 'var ')
            expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']

        describe "when lines are both updated and removed", ->
          it "updates tokens to reflect the change", ->
            buffer.setTextInRange([[1, 0], [3, 0]], "foo()")

            # previous line 0 remains
            expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[0]).toEqual(value: 'var', scopes: ['source.js', 'storage.modifier.js'])

            # previous line 3 should be combined with input to form line 1
            expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[0]).toEqual(value: 'foo', scopes: ['source.js'])
            expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[6]).toEqual(value: '=', scopes: ['source.js', 'keyword.operator.js'])

            # lines below deleted regions should be shifted upward
            expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[2]).toEqual(value: 'while', scopes: ['source.js', 'keyword.control.js'])
            expect(tokenizedBuffer.tokenizedLineForRow(3).tokens[4]).toEqual(value: '=', scopes: ['source.js', 'keyword.operator.js'])
            expect(tokenizedBuffer.tokenizedLineForRow(4).tokens[4]).toEqual(value: '<', scopes: ['source.js', 'keyword.operator.js'])

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 0, end: 3, delta: -2) # starts at 0 because foldable on row 0 becomes false

        describe "when the change invalidates the tokenization of subsequent lines", ->
          it "schedules the invalidated lines to be tokenized in the background", ->
            buffer.insert([5, 30], '/* */')
            changeHandler.reset()

            buffer.setTextInRange([[2, 0], [3, 0]], '/*')
            expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[0].scopes).toEqual ['source.js', 'comment.block.js', 'punctuation.definition.comment.js']
            expect(tokenizedBuffer.tokenizedLineForRow(3).tokens[0].scopes).toEqual ['source.js']
            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 1, end: 3, delta: -1)
            changeHandler.reset()

            advanceClock()
            expect(tokenizedBuffer.tokenizedLineForRow(3).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.tokenizedLineForRow(4).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            # we discover that row 2 starts a foldable region when line 3 gets tokenized
            expect(event).toEqual(start: 2, end: 4, delta: 0)

        describe "when lines are both updated and inserted", ->
          it "updates tokens to reflect the change", ->
            buffer.setTextInRange([[1, 0], [2, 0]], "foo()\nbar()\nbaz()\nquux()")

            # previous line 0 remains
            expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[0]).toEqual( value: 'var', scopes: ['source.js', 'storage.modifier.js'])

            # 3 new lines inserted
            expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[0]).toEqual(value: 'foo', scopes: ['source.js'])
            expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[0]).toEqual(value: 'bar', scopes: ['source.js'])
            expect(tokenizedBuffer.tokenizedLineForRow(3).tokens[0]).toEqual(value: 'baz', scopes: ['source.js'])

            # previous line 2 is joined with quux() on line 4
            expect(tokenizedBuffer.tokenizedLineForRow(4).tokens[0]).toEqual(value: 'quux', scopes: ['source.js'])
            expect(tokenizedBuffer.tokenizedLineForRow(4).tokens[4]).toEqual(value: 'if', scopes: ['source.js', 'keyword.control.js'])

            # previous line 3 is pushed down to become line 5
            expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[4]).toEqual(value: '=', scopes: ['source.js', 'keyword.operator.js'])

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 0, end: 2, delta: 2) # starts at 0 because .foldable becomes false on row 0

        describe "when the change invalidates the tokenization of subsequent lines", ->
          it "schedules the invalidated lines to be tokenized in the background", ->
            buffer.insert([5, 30], '/* */')
            changeHandler.reset()

            buffer.insert([2, 0], '/*\nabcde\nabcder')
            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 1, end: 2, delta: 2)
            expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[0].scopes).toEqual ['source.js', 'comment.block.js', 'punctuation.definition.comment.js']
            expect(tokenizedBuffer.tokenizedLineForRow(3).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.tokenizedLineForRow(4).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[0].scopes).toEqual ['source.js']
            changeHandler.reset()

            advanceClock() # tokenize invalidated lines in background
            expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.tokenizedLineForRow(6).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.tokenizedLineForRow(7).tokens[0].scopes).toEqual ['source.js', 'comment.block.js']
            expect(tokenizedBuffer.tokenizedLineForRow(8).tokens[0].scopes).not.toBe ['source.js', 'comment.block.js']

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            delete event.bufferChange
            expect(event).toEqual(start: 5, end: 7, delta: 0)

      describe "when there is an insertion that is larger than the chunk size", ->
        it "tokenizes the initial chunk synchronously, then tokenizes the remaining lines in the background", ->
          commentBlock = _.multiplyString("// a comment\n", tokenizedBuffer.chunkSize + 2)
          buffer.insert([0,0], commentBlock)
          expect(tokenizedBuffer.tokenizedLineForRow(0).ruleStack?).toBeTruthy()
          expect(tokenizedBuffer.tokenizedLineForRow(4).ruleStack?).toBeTruthy()
          expect(tokenizedBuffer.tokenizedLineForRow(5).ruleStack?).toBeFalsy()

          advanceClock()
          expect(tokenizedBuffer.tokenizedLineForRow(5).ruleStack?).toBeTruthy()
          expect(tokenizedBuffer.tokenizedLineForRow(6).ruleStack?).toBeTruthy()

      describe ".findOpeningBracket(closingBufferPosition)", ->
        it "returns the position of the matching bracket, skipping any nested brackets", ->
          expect(tokenizedBuffer.findOpeningBracket([9, 2])).toEqual [1, 29]

      describe ".findClosingBracket(startBufferPosition)", ->
        it "returns the position of the matching bracket, skipping any nested brackets", ->
          expect(tokenizedBuffer.findClosingBracket([1, 29])).toEqual [9, 2]

      it "tokenizes leading whitespace based on the new tab length", ->
        expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[0].isAtomic).toBeTruthy()
        expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[0].value).toBe "  "
        expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[1].isAtomic).toBeTruthy()
        expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[1].value).toBe "  "

        tokenizedBuffer.setTabLength(4)
        fullyTokenize(tokenizedBuffer)

        expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[0].isAtomic).toBeTruthy()
        expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[0].value).toBe "    "
        expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[1].isAtomic).toBeFalsy()
        expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[1].value).toBe "  current "

      it "does not tokenize whitespaces followed by combining characters as leading whitespace", ->
        buffer.setText("    \u030b")
        fullyTokenize(tokenizedBuffer)

        {tokens} = tokenizedBuffer.tokenizedLineForRow(0)
        expect(tokens[0].value).toBe "  "
        expect(tokens[0].hasLeadingWhitespace()).toBe true
        expect(tokens[1].value).toBe " "
        expect(tokens[1].hasLeadingWhitespace()).toBe true
        expect(tokens[2].value).toBe " \u030b"
        expect(tokens[2].hasLeadingWhitespace()).toBe false

  describe "when the buffer contains hard-tabs", ->
    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage('language-coffee-script')

      runs ->
        buffer = atom.project.bufferForPathSync('sample-with-tabs.coffee')
        tokenizedBuffer = new TokenizedBuffer({buffer})
        startTokenizing(tokenizedBuffer)

    afterEach ->
      tokenizedBuffer.destroy()
      buffer.release()

    describe "when the buffer is fully tokenized", ->
      beforeEach ->
        fullyTokenize(tokenizedBuffer)

      it "renders each tab as its own atomic token with a value of size tabLength", ->
        tabAsSpaces = _.multiplyString(' ', tokenizedBuffer.getTabLength())
        screenLine0 = tokenizedBuffer.tokenizedLineForRow(0)
        expect(screenLine0.text).toBe "# Econ 101#{tabAsSpaces}"
        { tokens } = screenLine0

        expect(tokens.length).toBe 4
        expect(tokens[0].value).toBe "#"
        expect(tokens[1].value).toBe " Econ 101"
        expect(tokens[2].value).toBe tabAsSpaces
        expect(tokens[2].scopes).toEqual tokens[1].scopes
        expect(tokens[2].isAtomic).toBeTruthy()
        expect(tokens[3].value).toBe ""

        expect(tokenizedBuffer.tokenizedLineForRow(2).text).toBe "#{tabAsSpaces} buy()#{tabAsSpaces}while supply > demand"

      it "aligns the hard tabs to the correct tab stop column", ->
        buffer.setText """
          1\t2 \t3\t4
          12\t3  \t4\t5
          123\t4   \t5\t6
        """

        tokenizedBuffer.setTabLength(4)
        fullyTokenize(tokenizedBuffer)

        expect(tokenizedBuffer.tokenizedLineForRow(0).text).toBe "1   2   3   4"
        expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[1].screenDelta).toBe 3

        expect(tokenizedBuffer.tokenizedLineForRow(1).text).toBe "12  3   4   5"
        expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[1].screenDelta).toBe 2

        expect(tokenizedBuffer.tokenizedLineForRow(2).text).toBe "123 4       5   6"
        expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[1].screenDelta).toBe 1

        tokenizedBuffer.setTabLength(3)
        fullyTokenize(tokenizedBuffer)

        expect(tokenizedBuffer.tokenizedLineForRow(0).text).toBe "1  2  3  4"
        expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[1].screenDelta).toBe 2

        expect(tokenizedBuffer.tokenizedLineForRow(1).text).toBe "12 3     4  5"
        expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[1].screenDelta).toBe 1

        expect(tokenizedBuffer.tokenizedLineForRow(2).text).toBe "123   4     5  6"
        expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[1].screenDelta).toBe 3

        tokenizedBuffer.setTabLength(2)
        fullyTokenize(tokenizedBuffer)

        expect(tokenizedBuffer.tokenizedLineForRow(0).text).toBe "1 2   3 4"
        expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[1].screenDelta).toBe 1

        expect(tokenizedBuffer.tokenizedLineForRow(1).text).toBe "12  3   4 5"
        expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[1].screenDelta).toBe 2

        expect(tokenizedBuffer.tokenizedLineForRow(2).text).toBe "123 4     5 6"
        expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[1].screenDelta).toBe 1

        tokenizedBuffer.setTabLength(1)
        fullyTokenize(tokenizedBuffer)

        expect(tokenizedBuffer.tokenizedLineForRow(0).text).toBe "1 2  3 4"
        expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[1].screenDelta).toBe 1

        expect(tokenizedBuffer.tokenizedLineForRow(1).text).toBe "12 3   4 5"
        expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[1].screenDelta).toBe 1

        expect(tokenizedBuffer.tokenizedLineForRow(2).text).toBe "123 4    5 6"
        expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[1].bufferDelta).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[1].screenDelta).toBe 1

  describe "when the buffer contains UTF-8 surrogate pairs", ->
    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage('language-javascript')

      runs ->
        buffer = atom.project.bufferForPathSync 'sample-with-pairs.js'
        buffer.setText """
          'abc\uD835\uDF97def'
          //\uD835\uDF97xyz
        """
        tokenizedBuffer = new TokenizedBuffer({buffer})
        fullyTokenize(tokenizedBuffer)

    afterEach ->
      tokenizedBuffer.destroy()
      buffer.release()

    it "renders each UTF-8 surrogate pair as its own atomic token", ->
      screenLine0 = tokenizedBuffer.tokenizedLineForRow(0)
      expect(screenLine0.text).toBe "'abc\uD835\uDF97def'"
      { tokens } = screenLine0

      expect(tokens.length).toBe 5
      expect(tokens[0].value).toBe "'"
      expect(tokens[1].value).toBe "abc"
      expect(tokens[2].value).toBe "\uD835\uDF97"
      expect(tokens[2].isAtomic).toBeTruthy()
      expect(tokens[3].value).toBe "def"
      expect(tokens[4].value).toBe "'"

      screenLine1 = tokenizedBuffer.tokenizedLineForRow(1)
      expect(screenLine1.text).toBe "//\uD835\uDF97xyz"
      { tokens } = screenLine1

      expect(tokens.length).toBe 4
      expect(tokens[0].value).toBe '//'
      expect(tokens[1].value).toBe '\uD835\uDF97'
      expect(tokens[1].value).toBeTruthy()
      expect(tokens[2].value).toBe 'xyz'
      expect(tokens[3].value).toBe ''

  describe "when the grammar is tokenized", ->
    it "emits the `tokenized` event", ->
      editor = null
      tokenizedHandler = jasmine.createSpy("tokenized handler")

      waitsForPromise ->
        atom.project.open('sample.js').then (o) -> editor = o

      runs ->
        tokenizedBuffer = editor.displayBuffer.tokenizedBuffer
        tokenizedBuffer.onDidTokenize tokenizedHandler
        fullyTokenize(tokenizedBuffer)
        expect(tokenizedHandler.callCount).toBe(1)

    it "doesn't re-emit the `tokenized` event when it is re-tokenized", ->
      editor = null
      tokenizedHandler = jasmine.createSpy("tokenized handler")

      waitsForPromise ->
        atom.project.open('sample.js').then (o) -> editor = o

      runs ->
        tokenizedBuffer = editor.displayBuffer.tokenizedBuffer
        fullyTokenize(tokenizedBuffer)

        tokenizedBuffer.onDidTokenize tokenizedHandler
        editor.getBuffer().insert([0, 0], "'")
        fullyTokenize(tokenizedBuffer)
        expect(tokenizedHandler).not.toHaveBeenCalled()

  describe "when the grammar is updated because a grammar it includes is activated", ->
    it "re-emits the `tokenized` event", ->
      editor = null
      tokenizedBuffer = null
      tokenizedHandler = jasmine.createSpy("tokenized handler")

      waitsForPromise ->
        atom.project.open('coffee.coffee').then (o) -> editor = o

      runs ->
        tokenizedBuffer = editor.displayBuffer.tokenizedBuffer
        tokenizedBuffer.onDidTokenize tokenizedHandler
        fullyTokenize(tokenizedBuffer)
        tokenizedHandler.reset()

      waitsForPromise ->
        atom.packages.activatePackage('language-coffee-script')

      runs ->
        fullyTokenize(tokenizedBuffer)
        expect(tokenizedHandler.callCount).toBe(1)

    it "retokenizes the buffer", ->

      waitsForPromise ->
        atom.packages.activatePackage('language-ruby-on-rails')

      waitsForPromise ->
        atom.packages.activatePackage('language-ruby')

      runs ->
        buffer = atom.project.bufferForPathSync()
        buffer.setText "<div class='name'><%= User.find(2).full_name %></div>"
        tokenizedBuffer = new TokenizedBuffer({buffer})
        tokenizedBuffer.setGrammar(atom.grammars.selectGrammar('test.erb'))
        fullyTokenize(tokenizedBuffer)

        {tokens} = tokenizedBuffer.tokenizedLineForRow(0)
        expect(tokens[0]).toEqual value: "<div class='name'>", scopes: ["text.html.ruby"]

      waitsForPromise ->
        atom.packages.activatePackage('language-html')

      runs ->
        fullyTokenize(tokenizedBuffer)
        {tokens} = tokenizedBuffer.tokenizedLineForRow(0)
        expect(tokens[0]).toEqual value: '<', scopes: ["text.html.ruby","meta.tag.block.any.html","punctuation.definition.tag.begin.html"]

  describe ".tokenForPosition(position)", ->
    afterEach ->
      tokenizedBuffer.destroy()
      buffer.release()

    it "returns the correct token (regression)", ->
      buffer = atom.project.bufferForPathSync('sample.js')
      tokenizedBuffer = new TokenizedBuffer({buffer})
      fullyTokenize(tokenizedBuffer)
      expect(tokenizedBuffer.tokenForPosition([1,0]).scopes).toEqual ["source.js"]
      expect(tokenizedBuffer.tokenForPosition([1,1]).scopes).toEqual ["source.js"]
      expect(tokenizedBuffer.tokenForPosition([1,2]).scopes).toEqual ["source.js", "storage.modifier.js"]

  describe ".bufferRangeForScopeAtPosition(selector, position)", ->
    beforeEach ->
      buffer = atom.project.bufferForPathSync('sample.js')
      tokenizedBuffer = new TokenizedBuffer({buffer})
      fullyTokenize(tokenizedBuffer)

    describe "when the selector does not match the token at the position", ->
      it "returns a falsy value", ->
        expect(tokenizedBuffer.bufferRangeForScopeAtPosition('.bogus', [0, 1])).toBeFalsy()

    describe "when the selector matches a single token at the position", ->
      it "returns the range covered by the token", ->
        expect(tokenizedBuffer.bufferRangeForScopeAtPosition('.storage.modifier.js', [0, 1])).toEqual [[0, 0], [0, 3]]

    describe "when the selector matches a run of multiple tokens at the position", ->
      it "returns the range covered by all contigous tokens (within a single line)", ->
        expect(tokenizedBuffer.bufferRangeForScopeAtPosition('.function', [1, 18])).toEqual [[1, 6], [1, 28]]

  describe "when the editor.tabLength config value changes", ->
    it "updates the tab length of the tokenized lines", ->
      buffer = atom.project.bufferForPathSync('sample.js')
      buffer.setText('\ttest')
      tokenizedBuffer = new TokenizedBuffer({buffer})
      fullyTokenize(tokenizedBuffer)
      expect(tokenizedBuffer.tokenForPosition([0,0]).value).toBe '  '
      atom.config.set('editor.tabLength', 6)
      expect(tokenizedBuffer.tokenForPosition([0,0]).value).toBe '      '

    it "does not allow the tab length to be less than 1", ->
      buffer = atom.project.bufferForPathSync('sample.js')
      buffer.setText('\ttest')
      tokenizedBuffer = new TokenizedBuffer({buffer})
      fullyTokenize(tokenizedBuffer)
      expect(tokenizedBuffer.tokenForPosition([0,0]).value).toBe '  '
      atom.config.set('editor.tabLength', 1)
      expect(tokenizedBuffer.tokenForPosition([0,0]).value).toBe ' '
      atom.config.set('editor.tabLength', 0)
      expect(tokenizedBuffer.tokenForPosition([0,0]).value).toBe ' '

  describe "when the invisibles value changes", ->
    beforeEach ->

    it "updates the tokens with the appropriate invisible characters", ->
      buffer = new TextBuffer(text: "  \t a line with tabs\tand \tspaces \t ")
      tokenizedBuffer = new TokenizedBuffer({buffer})
      fullyTokenize(tokenizedBuffer)

      tokenizedBuffer.setInvisibles(space: 'S', tab: 'T')
      fullyTokenize(tokenizedBuffer)

      expect(tokenizedBuffer.tokenizedLineForRow(0).text).toBe "SST Sa line with tabsTand T spacesSTS"
      # Also needs to work for copies
      expect(tokenizedBuffer.tokenizedLineForRow(0).copy().text).toBe "SST Sa line with tabsTand T spacesSTS"

    it "assigns endOfLineInvisibles to tokenized lines", ->
      buffer = new TextBuffer(text: "a line that ends in a carriage-return-line-feed \r\na line that ends in just a line-feed\na line with no ending")
      tokenizedBuffer = new TokenizedBuffer({buffer})

      atom.config.set('editor.showInvisibles', true)
      tokenizedBuffer.setInvisibles(cr: 'R', eol: 'N')
      fullyTokenize(tokenizedBuffer)

      expect(tokenizedBuffer.tokenizedLineForRow(0).endOfLineInvisibles).toEqual ['R', 'N']
      expect(tokenizedBuffer.tokenizedLineForRow(1).endOfLineInvisibles).toEqual ['N']

      # Lines ending in soft wraps get no invisibles
      [left, right] = tokenizedBuffer.tokenizedLineForRow(0).softWrapAt(20)
      expect(left.endOfLineInvisibles).toBe null
      expect(right.endOfLineInvisibles).toEqual ['R', 'N']

      tokenizedBuffer.setInvisibles(cr: 'R', eol: false)
      expect(tokenizedBuffer.tokenizedLineForRow(0).endOfLineInvisibles).toEqual ['R']
      expect(tokenizedBuffer.tokenizedLineForRow(1).endOfLineInvisibles).toEqual []

  describe "leading and trailing whitespace", ->
    beforeEach ->
      buffer = atom.project.bufferForPathSync('sample.js')
      tokenizedBuffer = new TokenizedBuffer({buffer})
      fullyTokenize(tokenizedBuffer)

    it "assigns ::firstNonWhitespaceIndex on tokens that have leading whitespace", ->
      expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[0].firstNonWhitespaceIndex).toBe null
      expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[0].firstNonWhitespaceIndex).toBe 2
      expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[1].firstNonWhitespaceIndex).toBe null

      expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[0].firstNonWhitespaceIndex).toBe 2
      expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[1].firstNonWhitespaceIndex).toBe 2
      expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[2].firstNonWhitespaceIndex).toBe null

      # The 4th token *has* leading whitespace, but isn't entirely whitespace
      buffer.insert([5, 0], ' ')
      expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[3].firstNonWhitespaceIndex).toBe 1
      expect(tokenizedBuffer.tokenizedLineForRow(5).tokens[4].firstNonWhitespaceIndex).toBe null

      # Lines that are *only* whitespace are not considered to have leading whitespace
      buffer.insert([10, 0], '  ')
      expect(tokenizedBuffer.tokenizedLineForRow(10).tokens[0].firstNonWhitespaceIndex).toBe null

    it "assigns ::firstTrailingWhitespaceIndex on tokens that have trailing whitespace", ->
      buffer.insert([0, Infinity], '  ')
      expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[11].firstTrailingWhitespaceIndex).toBe null
      expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[12].firstTrailingWhitespaceIndex).toBe 0

      # The last token *has* trailing whitespace, but isn't entirely whitespace
      buffer.setTextInRange([[2, 39], [2, 40]], '  ')
      expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[14].firstTrailingWhitespaceIndex).toBe null
      expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[15].firstTrailingWhitespaceIndex).toBe 6

      # Lines that are *only* whitespace are considered to have trailing whitespace
      buffer.insert([10, 0], '  ')
      expect(tokenizedBuffer.tokenizedLineForRow(10).tokens[0].firstTrailingWhitespaceIndex).toBe 0

    it "only marks trailing whitespace on the last segment of a soft-wrapped line", ->
      buffer.insert([0, Infinity], '  ')
      tokenizedLine = tokenizedBuffer.tokenizedLineForRow(0)
      [segment1, segment2] = tokenizedLine.softWrapAt(16)
      expect(segment1.tokens[5].value).toBe ' '
      expect(segment1.tokens[5].firstTrailingWhitespaceIndex).toBe null
      expect(segment2.tokens[6].value).toBe '  '
      expect(segment2.tokens[6].firstTrailingWhitespaceIndex).toBe 0

    it "sets leading and trailing whitespace correctly on a line with invisible characters that is copied", ->
      buffer.setText("  \t a line with tabs\tand \tspaces \t ")

      tokenizedBuffer.setInvisibles(space: 'S', tab: 'T')
      fullyTokenize(tokenizedBuffer)

      line = tokenizedBuffer.tokenizedLineForRow(0).copy()
      expect(line.tokens[0].firstNonWhitespaceIndex).toBe 2
      expect(line.tokens[line.tokens.length - 1].firstTrailingWhitespaceIndex).toBe 0

    it "sets the ::firstNonWhitespaceIndex and ::firstTrailingWhitespaceIndex correctly when tokens are split for soft-wrapping", ->
      tokenizedBuffer.setInvisibles(space: 'S')
      buffer.setText(" token ")
      fullyTokenize(tokenizedBuffer)
      token = tokenizedBuffer.tokenizedLines[0].tokens[0]

      [leftToken, rightToken] = token.splitAt(1)
      expect(leftToken.hasInvisibleCharacters).toBe true
      expect(leftToken.firstNonWhitespaceIndex).toBe 1
      expect(leftToken.firstTrailingWhitespaceIndex).toBe null

      expect(leftToken.hasInvisibleCharacters).toBe true
      expect(rightToken.firstNonWhitespaceIndex).toBe null
      expect(rightToken.firstTrailingWhitespaceIndex).toBe 5

  describe ".indentLevel on tokenized lines", ->
    beforeEach ->
      buffer = atom.project.bufferForPathSync('sample.js')
      tokenizedBuffer = new TokenizedBuffer({buffer})
      fullyTokenize(tokenizedBuffer)

    describe "when the line is non-empty", ->
      it "has an indent level based on the leading whitespace on the line", ->
        expect(tokenizedBuffer.tokenizedLineForRow(0).indentLevel).toBe 0
        expect(tokenizedBuffer.tokenizedLineForRow(1).indentLevel).toBe 1
        expect(tokenizedBuffer.tokenizedLineForRow(2).indentLevel).toBe 2
        buffer.insert([2, 0], ' ')
        expect(tokenizedBuffer.tokenizedLineForRow(2).indentLevel).toBe 2.5

    describe "when the line is empty", ->
      it "assumes the indentation level of the first non-empty line below or above if one exists", ->
        buffer.insert([12, 0], '    ')
        buffer.insert([12, Infinity], '\n\n')
        expect(tokenizedBuffer.tokenizedLineForRow(13).indentLevel).toBe 2
        expect(tokenizedBuffer.tokenizedLineForRow(14).indentLevel).toBe 2

        buffer.insert([1, Infinity], '\n\n')
        expect(tokenizedBuffer.tokenizedLineForRow(2).indentLevel).toBe 2
        expect(tokenizedBuffer.tokenizedLineForRow(3).indentLevel).toBe 2

        buffer.setText('\n\n\n')
        expect(tokenizedBuffer.tokenizedLineForRow(1).indentLevel).toBe 0

    describe "when the changed lines are surrounded by whitespace-only lines", ->
      it "updates the indentLevel of empty lines that precede the change", ->
        expect(tokenizedBuffer.tokenizedLineForRow(12).indentLevel).toBe 0

        buffer.insert([12, 0], '\n')
        buffer.insert([13, 0], '  ')
        expect(tokenizedBuffer.tokenizedLineForRow(12).indentLevel).toBe 1

      it "updates empty line indent guides when the empty line is the last line", ->
        buffer.insert([12, 2], '\n')

        # The newline and he tab need to be in two different operations to surface the bug
        buffer.insert([12, 0], '  ')
        expect(tokenizedBuffer.tokenizedLineForRow(13).indentLevel).toBe 1

        buffer.insert([12, 0], '  ')
        expect(tokenizedBuffer.tokenizedLineForRow(13).indentLevel).toBe 2
        expect(tokenizedBuffer.tokenizedLineForRow(14)).not.toBeDefined()

      it "updates the indentLevel of empty lines surrounding a change that inserts lines", ->
        # create some new lines
        buffer.insert([7, 0], '\n\n')
        buffer.insert([5, 0], '\n\n')

        expect(tokenizedBuffer.tokenizedLineForRow(5).indentLevel).toBe 3
        expect(tokenizedBuffer.tokenizedLineForRow(6).indentLevel).toBe 3
        expect(tokenizedBuffer.tokenizedLineForRow(9).indentLevel).toBe 3
        expect(tokenizedBuffer.tokenizedLineForRow(10).indentLevel).toBe 3
        expect(tokenizedBuffer.tokenizedLineForRow(11).indentLevel).toBe 2

        tokenizedBuffer.onDidChange changeHandler = jasmine.createSpy('changeHandler')

        buffer.setTextInRange([[7, 0], [8, 65]], '        one\n        two\n        three\n        four')

        delete changeHandler.argsForCall[0][0].bufferChange
        expect(changeHandler).toHaveBeenCalledWith(start: 5, end: 10, delta: 2)

        expect(tokenizedBuffer.tokenizedLineForRow(5).indentLevel).toBe 4
        expect(tokenizedBuffer.tokenizedLineForRow(6).indentLevel).toBe 4
        expect(tokenizedBuffer.tokenizedLineForRow(11).indentLevel).toBe 4
        expect(tokenizedBuffer.tokenizedLineForRow(12).indentLevel).toBe 4
        expect(tokenizedBuffer.tokenizedLineForRow(13).indentLevel).toBe 2

      it "updates the indentLevel of empty lines surrounding a change that removes lines", ->
        # create some new lines
        buffer.insert([7, 0], '\n\n')
        buffer.insert([5, 0], '\n\n')

        tokenizedBuffer.onDidChange changeHandler = jasmine.createSpy('changeHandler')

        buffer.setTextInRange([[7, 0], [8, 65]], '    ok')

        delete changeHandler.argsForCall[0][0].bufferChange
        expect(changeHandler).toHaveBeenCalledWith(start: 4, end: 10, delta: -1) # starts at row 4 because it became foldable

        expect(tokenizedBuffer.tokenizedLineForRow(5).indentLevel).toBe 2
        expect(tokenizedBuffer.tokenizedLineForRow(6).indentLevel).toBe 2
        expect(tokenizedBuffer.tokenizedLineForRow(7).indentLevel).toBe 2 # new text
        expect(tokenizedBuffer.tokenizedLineForRow(8).indentLevel).toBe 2
        expect(tokenizedBuffer.tokenizedLineForRow(9).indentLevel).toBe 2
        expect(tokenizedBuffer.tokenizedLineForRow(10).indentLevel).toBe 2 # }

  describe ".foldable on tokenized lines", ->
    changes = null

    beforeEach ->
      changes = []
      buffer = atom.project.bufferForPathSync('sample.js')
      buffer.insert [10, 0], "  // multi-line\n  // comment\n  // block\n"
      buffer.insert [0, 0], "// multi-line\n// comment\n// block\n"
      tokenizedBuffer = new TokenizedBuffer({buffer})
      fullyTokenize(tokenizedBuffer)
      tokenizedBuffer.onDidChange (change) ->
        delete change.bufferChange
        changes.push(change)

    it "sets .foldable to true on the first line of multi-line comments", ->
      expect(tokenizedBuffer.tokenizedLineForRow(0).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(1).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(2).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(3).foldable).toBe true # because of indent
      expect(tokenizedBuffer.tokenizedLineForRow(13).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(14).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(15).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(16).foldable).toBe false

      buffer.insert([0, Infinity], '\n')
      expect(changes).toEqual [{start: 0, end: 1, delta: 1}]

      expect(tokenizedBuffer.tokenizedLineForRow(0).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(1).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(2).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(3).foldable).toBe false

      changes = []
      buffer.undo()
      expect(changes).toEqual [{start: 0, end: 2, delta: -1}]
      expect(tokenizedBuffer.tokenizedLineForRow(0).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(1).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(2).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(3).foldable).toBe true # because of indent

    it "sets .foldable to true on non-comment lines that precede an increase in indentation", ->
      buffer.insert([2, 0], '  ') # commented lines preceding an indent aren't foldable
      expect(tokenizedBuffer.tokenizedLineForRow(1).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(2).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(3).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(4).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(5).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(6).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(7).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(8).foldable).toBe false

      changes = []
      buffer.insert([7, 0], '  ')
      expect(changes).toEqual [{start: 6, end: 7, delta: 0}]
      expect(tokenizedBuffer.tokenizedLineForRow(6).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(7).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(8).foldable).toBe false

      changes = []
      buffer.undo()
      expect(changes).toEqual [{start: 6, end: 7, delta: 0}]
      expect(tokenizedBuffer.tokenizedLineForRow(6).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(7).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(8).foldable).toBe false

      changes = []
      buffer.insert([7, 0], "    \n      x\n")
      expect(changes).toEqual [{start: 6, end: 7, delta: 2}]
      expect(tokenizedBuffer.tokenizedLineForRow(6).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(7).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(8).foldable).toBe false

      changes = []
      buffer.insert([9, 0], "  ")
      expect(changes).toEqual [{start: 9, end: 9, delta: 0}]
      expect(tokenizedBuffer.tokenizedLineForRow(6).foldable).toBe true
      expect(tokenizedBuffer.tokenizedLineForRow(7).foldable).toBe false
      expect(tokenizedBuffer.tokenizedLineForRow(8).foldable).toBe false

  describe "when the buffer is configured with the null grammar", ->
    it "uses the placeholder tokens and does not actually tokenize using the grammar", ->
      spyOn(atom.grammars.nullGrammar, 'tokenizeLine').andCallThrough()
      buffer = atom.project.bufferForPathSync('sample.will-use-the-null-grammar')
      buffer.setText('a\nb\nc')

      tokenizedBuffer = new TokenizedBuffer({buffer})
      tokenizeCallback = jasmine.createSpy('onDidTokenize')
      tokenizedBuffer.onDidTokenize(tokenizeCallback)

      fullyTokenize(tokenizedBuffer)

      expect(tokenizeCallback.callCount).toBe 1
      expect(atom.grammars.nullGrammar.tokenizeLine.callCount).toBe 0

      expect(tokenizedBuffer.tokenizedLineForRow(0).tokens.length).toBe 1
      expect(tokenizedBuffer.tokenizedLineForRow(0).tokens[0].value).toBe 'a'
      expect(tokenizedBuffer.tokenizedLineForRow(1).tokens.length).toBe 1
      expect(tokenizedBuffer.tokenizedLineForRow(1).tokens[0].value).toBe 'b'
      expect(tokenizedBuffer.tokenizedLineForRow(2).tokens.length).toBe 1
      expect(tokenizedBuffer.tokenizedLineForRow(2).tokens[0].value).toBe 'c'
