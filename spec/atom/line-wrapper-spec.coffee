Buffer = require 'buffer'
LineWrapper = require 'line-wrapper'
Highlighter = require 'highlighter'
Range = require 'range'
_ = require 'underscore'

fdescribe "LineWrapper", ->
  [wrapper, buffer] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    wrapper = new LineWrapper(50, new Highlighter(buffer))

  describe ".screenLinesForBufferRow(bufferRow)", ->
    it "returns an array of tokens for each screen line associated with the buffer row", ->
      wrapper.setMaxLength(30)
      screenLines = wrapper.wrappedLines[6].screenLines

      expect(screenLines.length).toBe 3
      [line1, line2, line3] = screenLines

      # TODO: Get this working again after finalizing split tokens
      # expect(line1.endColumn).toBe 24
      # expect(tokensText(line1)).toBe '      current < pivot ? '

      # expect(line2.endColumn).toBe 45
      # expect(tokensText(line2)).toBe 'left.push(current) : '

      # expect(line3.endColumn).toBe 65
      # expect(tokensText(line3)).toBe 'right.push(current);'

  describe "when the buffer changes", ->
    changeHandler = null
    longText = '0123456789ABCDEF'

    beforeEach ->
      changeHandler = jasmine.createSpy('changeHandler')
      wrapper.on 'change', changeHandler

    describe "when an unwrapped line is updated", ->
      describe "when the update does not cause the line to wrap", ->
        it "updates tokens for the corresponding screen line and emits a change event", ->
          buffer.insert([0, 10], 'h')
          expect(tokensText(wrapper.tokensForScreenRow(0))).toContain 'quickshort'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual(new Range([0, 10], [0, 10]))
          expect(event.newRange).toEqual(new Range([0, 10], [0, 11]))
          changeHandler.reset()

          # below a wrapped line
          buffer.insert([4, 10], 'foo')
          expect(tokensText(wrapper.tokensForScreenRow(5))).toContain 'fooitems'
          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual(new Range([5, 10], [5, 10]))
          expect(event.newRange).toEqual(new Range([5, 10], [5, 13]))


      describe "when the update causes the line to wrap once", ->
        it "updates tokens for the corresponding screen lines and emits a change event", ->
          buffer.insert([2, 4], longText)
          expect(tokensText(wrapper.tokensForScreenRow(2))).toBe '    0123456789ABCDEFif (items.length <= 1) return '
          expect(tokensText(wrapper.tokensForScreenRow(3))).toBe 'items;'
          expect(tokensText(wrapper.tokensForScreenRow(4))).toBe '    var pivot = items.shift(), current, left = [], '

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual(new Range([2, 4], [2, 4]))
          expect(event.newRange).toEqual(new Range([2, 4], [3, 6]))

      describe "when the update causes the line to wrap multiple times", ->
        it "updates tokens for the corresponding screen lines and emits a change event", ->
          buffer.insert([2, 4], ["/*",longText, longText, longText, longText, "*/"].join(' '))
          expect(tokensText(wrapper.tokensForScreenRow(2))).toBe '    /* 0123456789ABCDEF 0123456789ABCDEF '
          expect(tokensText(wrapper.tokensForScreenRow(3))).toBe '0123456789ABCDEF 0123456789ABCDEF */if '
          expect(tokensText(wrapper.tokensForScreenRow(4))).toBe '(items.length <= 1) return items;'
          expect(tokensText(wrapper.tokensForScreenRow(5))).toBe '    var pivot = items.shift(), current, left = [], '

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual(new Range([2, 4], [2, 4]))
          expect(event.newRange).toEqual(new Range([2, 4], [4, 33]))

    describe "when a wrapped line is updated", ->
      describe "when the update does not cause the line to un-wrap", ->

      describe "when the update causes the line to no longer be wrapped", ->

      describe "when the update causes a line that was wrapped twice to be only wrapped once", ->

      describe "when the update causes the line to wrap a second time", ->

    describe "when a line is inserted", ->
      describe "when the line is wrapped", ->

      describe "when the line is not wrapped", ->

    describe "when a line is removed", ->
      describe "when the line is wrapped", ->

      describe "when the line is not wrapped", ->

  describe ".tokensForScreenRow(row)", ->
    it "returns tokens for the line fragment corresponding to the given screen row", ->
      expect(wrapper.tokensForScreenRow(3)).toEqual(wrapper.wrappedLines[3].screenLines[0])
      expect(wrapper.tokensForScreenRow(4)).toEqual(wrapper.wrappedLines[3].screenLines[1])
      expect(wrapper.tokensForScreenRow(5)).toEqual(wrapper.wrappedLines[4].screenLines[0])

  describe ".splitTokens(tokens)", ->
    makeTokens = (array) ->
      array.map (value) -> { value, type: 'foo' }

    beforeEach ->
      wrapper.setMaxLength(10)

    describe "when the line is shorter than max length", ->
      it "does not split the line", ->
        screenLines = wrapper.splitTokens(makeTokens ['abc', 'def'])
        expect(screenLines).toEqual [makeTokens ['abc', 'def']]

        [line1] = screenLines
        expect(line1.startColumn).toBe 0
        expect(line1.endColumn).toBe 6
        expect(line1.textLength).toBe 6

    describe "when there is a non-whitespace character at the max-length boundary", ->
      describe "when there is whitespace before the max-length boundary", ->
        it "splits the line at the start of the first word before the boundary", ->
          screenLines = wrapper.splitTokens(makeTokens ['12 ', '45 ', ' 89A', 'BC'])
          expect(screenLines.length).toBe 2
          [line1, line2] = screenLines
          expect(line1).toEqual(makeTokens ['12 ', '45 ', ' '])
          expect(line2).toEqual(makeTokens ['89A', 'BC'])

          expect(line1.startColumn).toBe 0
          expect(line1.endColumn).toBe 7
          expect(line1.textLength).toBe 7

          expect(line2.startColumn).toBe 7
          expect(line2.endColumn).toBe 12
          expect(line2.textLength).toBe 5

      describe "when there is no whitespace before the max-length boundary", ->
        it "splits the line at the boundary, because there's no 'good' place to split it", ->
          screenLines = wrapper.splitTokens(makeTokens ['123', '456', '789AB', 'CD'])
          expect(screenLines.length).toBe 2
          [line1, line2] = screenLines
          expect(line1).toEqual(makeTokens ['123', '456', '789A'])
          expect(line2).toEqual(makeTokens ['B', 'CD'])

          expect(line1.startColumn).toBe 0
          expect(line1.endColumn).toBe 10
          expect(line1.textLength).toBe 10

          expect(line2.startColumn).toBe 10
          expect(line2.endColumn).toBe 13
          expect(line2.textLength).toBe 3

    describe "when there is a whitespace character at the max-length boundary", ->
      it "splits the line at the start of the first word beyond the boundary", ->
          screenLines = wrapper.splitTokens(makeTokens ['12 ', '45 ', ' 89  C', 'DE'])
          expect(screenLines.length).toBe 2
          [line1, line2] = screenLines
          expect(line1).toEqual(makeTokens ['12 ', '45 ', ' 89  '])
          expect(line2).toEqual(makeTokens ['C', 'DE'])

          expect(line1.startColumn).toBe 0
          expect(line1.endColumn).toBe 11
          expect(line1.textLength).toBe 11

          expect(line2.startColumn).toBe 11
          expect(line2.endColumn).toBe 14
          expect(line2.textLength).toBe 3

  describe ".screenPositionFromBufferPosition(point)", ->
    it "translates the given buffer position to a screen position, accounting for wrapped lines", ->
      # before any wrapped lines
      expect(wrapper.screenPositionFromBufferPosition([0, 5])).toEqual([0, 5])

      # on a wrapped line
      expect(wrapper.screenPositionFromBufferPosition([3, 5])).toEqual([3, 5])
      expect(wrapper.screenPositionFromBufferPosition([3, 50])).toEqual([3, 50])
      expect(wrapper.screenPositionFromBufferPosition([3, 51])).toEqual([4, 0])

      # following a wrapped line
      expect(wrapper.screenPositionFromBufferPosition([4, 5])).toEqual([5, 5])

  describe ".bufferPositionFromScreenPosition(point)", ->
    it "translates the given screen position to a buffer position, account for wrapped lines", ->
      # before any wrapped lines
      expect(wrapper.bufferPositionFromScreenPosition([0, 5])).toEqual([0, 5])

      # on a wrapped line
      expect(wrapper.bufferPositionFromScreenPosition([3, 5])).toEqual([3, 5])
      expect(wrapper.bufferPositionFromScreenPosition([4, 0])).toEqual([3, 51])
      expect(wrapper.bufferPositionFromScreenPosition([4, 5])).toEqual([3, 56])

      # following a wrapped line
      expect(wrapper.bufferPositionFromScreenPosition([5, 5])).toEqual([4, 5])

