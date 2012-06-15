TokenizedBuffer = require 'tokenized-buffer'
Buffer = require 'buffer'
Range = require 'range'

describe "TokenizedBuffer", ->
  [tokenizedBuffer, buffer] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    tokenizedBuffer = new TokenizedBuffer(buffer, '  ')

  describe ".findClosingBracket(startBufferPosition)", ->
    it "returns the position of the matching bracket, skipping any nested brackets", ->
      expect(tokenizedBuffer.findClosingBracket([1, 29])).toEqual [9, 2]

  describe ".findOpeningBracket(closingBufferPosition)", ->
    it "returns the position of the matching bracket, skipping any nested brackets", ->
      expect(tokenizedBuffer.findOpeningBracket([9, 2])).toEqual [1, 29]

  describe ".toggleLineCommentsInRange(range)", ->
    describe "javascript", ->
      it "comments/uncomments lines in the given range", ->
        tokenizedBuffer.toggleLineCommentsInRange([[4, 5], [7, 8]])
        expect(buffer.lineForRow(4)).toBe "//    while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "//      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "//      current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "//    }"

        tokenizedBuffer.toggleLineCommentsInRange([[4, 5], [5, 8]])
        expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "//      current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "//    }"

    describe "coffeescript", ->
      it "comments/uncomments lines in the given range", ->
        buffer = new Buffer(require.resolve('fixtures/coffee.coffee'))
        tokenizedBuffer = new TokenizedBuffer(buffer, '  ')

        tokenizedBuffer.toggleLineCommentsInRange([[4, 5], [7, 8]])
        expect(buffer.lineForRow(4)).toBe "    #pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "    #left = []"
        expect(buffer.lineForRow(6)).toBe "    #right = []"
        expect(buffer.lineForRow(7)).toBe "#"

        tokenizedBuffer.toggleLineCommentsInRange([[4, 5], [5, 8]])
        expect(buffer.lineForRow(4)).toBe "    pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "    left = []"
        expect(buffer.lineForRow(6)).toBe "    #right = []"
        expect(buffer.lineForRow(7)).toBe "#"

  describe "fold suggestion", ->
    describe "javascript", ->
      beforeEach ->
        buffer = new Buffer(require.resolve 'fixtures/sample.js')
        tokenizedBuffer = new TokenizedBuffer(buffer)

      describe ".isBufferRowFoldable(bufferRow)", ->
        it "returns true only when the buffer row starts a foldable region", ->
          expect(tokenizedBuffer.isBufferRowFoldable(0)).toBeTruthy()
          expect(tokenizedBuffer.isBufferRowFoldable(1)).toBeTruthy()
          expect(tokenizedBuffer.isBufferRowFoldable(2)).toBeFalsy()
          expect(tokenizedBuffer.isBufferRowFoldable(3)).toBeFalsy()

      describe ".rowRangeForFoldAtBufferRow(bufferRow)", ->
        it "returns the start/end rows of the foldable region starting at the given row", ->
          expect(tokenizedBuffer.rowRangeForFoldAtBufferRow(0)).toEqual [0, 12]
          expect(tokenizedBuffer.rowRangeForFoldAtBufferRow(1)).toEqual [1, 9]
          expect(tokenizedBuffer.rowRangeForFoldAtBufferRow(2)).toBeNull()
          expect(tokenizedBuffer.rowRangeForFoldAtBufferRow(4)).toEqual [4, 7]

    describe "coffeescript", ->
      beforeEach ->
        buffer = new Buffer(require.resolve 'fixtures/coffee.coffee')
        tokenizedBuffer = new TokenizedBuffer(buffer)

      describe ".isBufferRowFoldable(bufferRow)", ->
        it "returns true only when the buffer row starts a foldable region", ->
          expect(tokenizedBuffer.isBufferRowFoldable(0)).toBeTruthy()
          expect(tokenizedBuffer.isBufferRowFoldable(1)).toBeTruthy()
          expect(tokenizedBuffer.isBufferRowFoldable(2)).toBeFalsy()
          expect(tokenizedBuffer.isBufferRowFoldable(3)).toBeFalsy()
          expect(tokenizedBuffer.isBufferRowFoldable(19)).toBeTruthy()

      describe ".rowRangeForFoldAtBufferRow(bufferRow)", ->
        it "returns the start/end rows of the foldable region starting at the given row", ->
          expect(tokenizedBuffer.rowRangeForFoldAtBufferRow(0)).toEqual [0, 20]
          expect(tokenizedBuffer.rowRangeForFoldAtBufferRow(1)).toEqual [1, 17]
          expect(tokenizedBuffer.rowRangeForFoldAtBufferRow(2)).toBeNull()
          expect(tokenizedBuffer.rowRangeForFoldAtBufferRow(19)).toEqual [19, 20]

  describe "tokenization", ->
    it "tokenizes all the lines in the buffer on construction", ->
      expect(tokenizedBuffer.lineForScreenRow(0).tokens[0]).toEqual(type: 'keyword.definition', value: 'var')
      expect(tokenizedBuffer.lineForScreenRow(11).tokens[1]).toEqual(type: 'keyword', value: 'return')

    describe "when the buffer changes", ->
      changeHandler = null

      beforeEach ->
        changeHandler = jasmine.createSpy('changeHandler')
        tokenizedBuffer.on "change", changeHandler

      describe "when lines are updated, but none are added or removed", ->
        it "updates tokens for each of the changed lines", ->
          range = new Range([0, 0], [2, 0])
          buffer.change(range, "foo()\nbar()\n")

          expect(tokenizedBuffer.lineForScreenRow(0).tokens[0]).toEqual(type: 'identifier', value: 'foo')
          expect(tokenizedBuffer.lineForScreenRow(1).tokens[0]).toEqual(type: 'identifier', value: 'bar')

          # line 2 is unchanged
          expect(tokenizedBuffer.lineForScreenRow(2).tokens[1]).toEqual(type: 'keyword', value: 'if')

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
      tabText = null

      beforeEach ->
        tabText = '  '
        buffer = new Buffer(require.resolve('fixtures/sample-with-tabs.coffee'))
        tokenizedBuffer = new TokenizedBuffer(buffer, tabText)

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
