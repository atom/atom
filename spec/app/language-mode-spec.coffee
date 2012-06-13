LanguageMode = require 'language-mode'
Buffer = require 'buffer'
Range = require 'range'

describe "LanguageMode", ->
  [languageMode, buffer] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    languageMode = new LanguageMode(buffer)

  describe ".findClosingBracket(startBracketPosition)", ->
    describe "when called with a bracket type of '{'", ->
      it "returns the position of the matching bracket, skipping any nested brackets", ->
        expect(languageMode.findClosingBracket([1, 29])).toEqual [9, 2]

  describe ".toggleLineCommentsInRange(range)", ->
    it "comments/uncomments lines in the given range", ->
      languageMode.toggleLineCommentsInRange([[4, 5], [7, 8]])
      expect(buffer.lineForRow(4)).toBe "//    while(items.length > 0) {"
      expect(buffer.lineForRow(5)).toBe "//      current = items.shift();"
      expect(buffer.lineForRow(6)).toBe "//      current < pivot ? left.push(current) : right.push(current);"
      expect(buffer.lineForRow(7)).toBe "//    }"

      languageMode.toggleLineCommentsInRange([[4, 5], [5, 8]])
      expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
      expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
      expect(buffer.lineForRow(6)).toBe "//      current < pivot ? left.push(current) : right.push(current);"
      expect(buffer.lineForRow(7)).toBe "//    }"

  describe "fold suggestion", ->
    describe "javascript", ->
      beforeEach ->
        buffer = new Buffer(require.resolve 'fixtures/sample.js')
        languageMode = new LanguageMode(buffer)

      describe ".isBufferRowFoldable(bufferRow)", ->
        it "returns true only when the buffer row starts a foldable region", ->
          expect(languageMode.isBufferRowFoldable(0)).toBeTruthy()
          expect(languageMode.isBufferRowFoldable(1)).toBeTruthy()
          expect(languageMode.isBufferRowFoldable(2)).toBeFalsy()
          expect(languageMode.isBufferRowFoldable(3)).toBeFalsy()

      describe ".rowRangeForFoldAtBufferRow(bufferRow)", ->
        it "returns the start/end rows of the foldable region starting at the given row", ->
          expect(languageMode.rowRangeForFoldAtBufferRow(0)).toEqual [0, 12]
          expect(languageMode.rowRangeForFoldAtBufferRow(1)).toEqual [1, 9]
          expect(languageMode.rowRangeForFoldAtBufferRow(2)).toBeNull()
          expect(languageMode.rowRangeForFoldAtBufferRow(4)).toEqual [4, 7]

    describe "coffeescript", ->
      beforeEach ->
        buffer = new Buffer(require.resolve 'fixtures/coffee.coffee')
        languageMode = new LanguageMode(buffer)

      describe ".isBufferRowFoldable(bufferRow)", ->
        it "returns true only when the buffer row starts a foldable region", ->
          expect(languageMode.isBufferRowFoldable(0)).toBeTruthy()
          expect(languageMode.isBufferRowFoldable(1)).toBeTruthy()
          expect(languageMode.isBufferRowFoldable(2)).toBeFalsy()
          expect(languageMode.isBufferRowFoldable(3)).toBeFalsy()
          expect(languageMode.isBufferRowFoldable(19)).toBeTruthy()

      describe ".rowRangeForFoldAtBufferRow(bufferRow)", ->
        it "returns the start/end rows of the foldable region starting at the given row", ->
          expect(languageMode.rowRangeForFoldAtBufferRow(0)).toEqual [0, 20]
          expect(languageMode.rowRangeForFoldAtBufferRow(1)).toEqual [1, 17]
          expect(languageMode.rowRangeForFoldAtBufferRow(2)).toBeNull()
          expect(languageMode.rowRangeForFoldAtBufferRow(19)).toEqual [19, 20]

  describe "tokenization", ->
    it "tokenizes all the lines in the buffer on construction", ->
      expect(languageMode.lineForScreenRow(0).tokens[0]).toEqual(type: 'keyword.definition', value: 'var')
      expect(languageMode.lineForScreenRow(11).tokens[1]).toEqual(type: 'keyword', value: 'return')

    describe "when the buffer changes", ->
      changeHandler = null

      beforeEach ->
        changeHandler = jasmine.createSpy('changeHandler')
        languageMode.on "change", changeHandler

      describe "when lines are updated, but none are added or removed", ->
        it "updates tokens for each of the changed lines", ->
          range = new Range([0, 0], [2, 0])
          buffer.change(range, "foo()\nbar()\n")

          expect(languageMode.lineForScreenRow(0).tokens[0]).toEqual(type: 'identifier', value: 'foo')
          expect(languageMode.lineForScreenRow(1).tokens[0]).toEqual(type: 'identifier', value: 'bar')

          # line 2 is unchanged
          expect(languageMode.lineForScreenRow(2).tokens[1]).toEqual(type: 'keyword', value: 'if')

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]

          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual new Range([0, 0], [2,0])

        it "updates tokens for lines beyond the changed lines if needed", ->
          buffer.insert([5, 30], '/* */')
          changeHandler.reset()

          buffer.insert([2, 0], '/*')
          expect(languageMode.lineForScreenRow(3).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(4).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(5).tokens[0].type).toBe 'comment'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(5).length])
          expect(event.newRange).toEqual new Range([2, 0], [5, buffer.lineForRow(5).length])

        it "resumes highlighting with the state of the previous line", ->
          buffer.insert([0, 0], '/*')
          buffer.insert([5, 0], '*/')

          buffer.insert([1, 0], 'var ')
          expect(languageMode.lineForScreenRow(1).tokens[0].type).toBe 'comment'

      describe "when lines are both updated and removed", ->
        it "updates tokens to reflect the removed lines", ->
          range = new Range([1, 0], [3, 0])
          buffer.change(range, "foo()")

          # previous line 0 remains
          expect(languageMode.lineForScreenRow(0).tokens[0]).toEqual(type: 'keyword.definition', value: 'var')

          # previous line 3 should be combined with input to form line 1
          expect(languageMode.lineForScreenRow(1).tokens[0]).toEqual(type: 'identifier', value: 'foo')
          expect(languageMode.lineForScreenRow(1).tokens[6]).toEqual(type: 'identifier', value: 'pivot')

          # lines below deleted regions should be shifted upward
          expect(languageMode.lineForScreenRow(2).tokens[1]).toEqual(type: 'keyword', value: 'while')
          expect(languageMode.lineForScreenRow(3).tokens[1]).toEqual(type: 'identifier', value: 'current')
          expect(languageMode.lineForScreenRow(4).tokens[3]).toEqual(type: 'keyword.operator', value: '<')

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual new Range([1, 0], [1, 5])

        it "updates tokens for lines beyond the changed lines if needed", ->
          buffer.insert([5, 30], '/* */')
          changeHandler.reset()

          buffer.change(new Range([2, 0], [3, 0]), '/*')
          expect(languageMode.lineForScreenRow(2).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(3).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(4).tokens[0].type).toBe 'comment'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(4).length])
          expect(event.newRange).toEqual new Range([2, 0], [4, buffer.lineForRow(4).length])

      describe "when lines are both updated and inserted", ->
        it "updates tokens to reflect the inserted lines", ->
          range = new Range([1, 0], [2, 0])
          buffer.change(range, "foo()\nbar()\nbaz()\nquux()")

          # previous line 0 remains
          expect(languageMode.lineForScreenRow(0).tokens[0]).toEqual(type: 'keyword.definition', value: 'var')

          # 3 new lines inserted
          expect(languageMode.lineForScreenRow(1).tokens[0]).toEqual(type: 'identifier', value: 'foo')
          expect(languageMode.lineForScreenRow(2).tokens[0]).toEqual(type: 'identifier', value: 'bar')
          expect(languageMode.lineForScreenRow(3).tokens[0]).toEqual(type: 'identifier', value: 'baz')

          # previous line 2 is joined with quux() on line 4
          expect(languageMode.lineForScreenRow(4).tokens[0]).toEqual(type: 'identifier', value: 'quux')
          expect(languageMode.lineForScreenRow(4).tokens[4]).toEqual(type: 'keyword', value: 'if')

          # previous line 3 is pushed down to become line 5
          expect(languageMode.lineForScreenRow(5).tokens[3]).toEqual(type: 'identifier', value: 'pivot')

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual new Range([1, 0], [4, 6])

        it "updates tokens for lines beyond the changed lines if needed", ->
          buffer.insert([5, 30], '/* */')
          changeHandler.reset()

          buffer.insert([2, 0], '/*\nabcde\nabcder')
          expect(languageMode.lineForScreenRow(2).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(3).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(4).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(5).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(6).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(7).tokens[0].type).toBe 'comment'
          expect(languageMode.lineForScreenRow(8).tokens[0].type).not.toBe 'comment'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(7).length])
          expect(event.newRange).toEqual new Range([2, 0], [7, buffer.lineForRow(7).length])

    describe "when the buffer contains tab characters", ->
      tabText = null

      beforeEach ->
        tabText = '  '
        buffer = new Buffer(require.resolve('fixtures/sample-with-tabs.coffee'))
        languageMode = new LanguageMode(buffer, tabText)

      it "always renders each tab as its own atomic token containing tabText", ->
        screenLine0 = languageMode.lineForScreenRow(0)
        expect(screenLine0.text).toBe "# Econ 101#{tabText}"
        { tokens } = screenLine0
        expect(tokens.length).toBe 2
        expect(tokens[0].value).toBe "# Econ 101"
        expect(tokens[1].value).toBe tabText
        expect(tokens[1].type).toBe tokens[0].type
        expect(tokens[1].isAtomic).toBeTruthy()

        expect(languageMode.lineForScreenRow(2).text).toBe "#{tabText} buy()#{tabText}while supply > demand"

