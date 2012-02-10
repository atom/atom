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

  describe ".tokensForScreenRow(row)", ->
    it "returns tokens for the line fragment corresponding to the given screen row", ->
      expect(tokensText wrapper.tokensForScreenRow(3)).toEqual('    var pivot = items.shift(), current, left = [], ')
      expect(tokensText wrapper.tokensForScreenRow(4)).toEqual('right = [];')
      expect(tokensText wrapper.tokensForScreenRow(5)).toEqual('    while(items.length > 0) {')

  describe "when the buffer changes", ->
    changeHandler = null
    longText = '0123456789ABCDEF'
    text10 = '0123456789'
    text60 = '0123456789 123456789 123456789 123456789 123456789 123456789'

    beforeEach ->
      changeHandler = jasmine.createSpy('changeHandler')
      wrapper.on 'change', changeHandler

    describe "when a buffer line is updated", ->
      describe "when the number of screen lines remains the same for the changed buffer line", ->
        it "re-wraps the existing lines and emits a change event for all its screen lines", ->
          buffer.insert([6, 28], '1234567')
          expect(tokensText(wrapper.tokensForScreenRow(7))).toBe '      current < pivot ? left1234567.push(current) '
          expect(tokensText(wrapper.tokensForScreenRow(8))).toBe ': right.push(current);'
          expect(tokensText(wrapper.tokensForScreenRow(9))).toBe '    }'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[7, 0], [8, 20]])
          expect(event.newRange).toEqual([[7, 0], [8, 22]])

      describe "when the number of screen lines increases for the changed buffer line", ->
        it "re-wraps and adds an additional screen line and emits a change event for all screen lines", ->
          buffer.insert([6, 28], '1234567890')
          expect(tokensText(wrapper.tokensForScreenRow(7))).toBe '      current < pivot ? '
          expect(tokensText(wrapper.tokensForScreenRow(8))).toBe 'left1234567890.push(current) : '
          expect(tokensText(wrapper.tokensForScreenRow(9))).toBe 'right.push(current);'
          expect(tokensText(wrapper.tokensForScreenRow(10))).toBe '    }'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[7, 0], [8, 20]])
          expect(event.newRange).toEqual([[7, 0], [9, 20]])

      describe "when the number of screen lines decreases for the changed buffer line", ->
        it "re-wraps and removes a screen line and emits a change event for all screen lines", ->
          buffer.change(new Range([6, 24], [6, 42]), '')
          expect(tokensText(wrapper.tokensForScreenRow(7))).toBe '      current < pivot ?  : right.push(current);'
          expect(tokensText(wrapper.tokensForScreenRow(8))).toBe '    }'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[7, 0], [8, 20]])
          expect(event.newRange).toEqual([[7, 0], [7, 47]])

    describe "when buffer lines are inserted", ->
      it "re-wraps existing and new screen lines and emits a change event", ->
        buffer.insert([6, 21], '1234567890 abcdefghij 1234567890\nabcdefghij')
        expect(tokensText(wrapper.tokensForScreenRow(7))).toBe '      current < pivot1234567890 abcdefghij '
        expect(tokensText(wrapper.tokensForScreenRow(8))).toBe '1234567890'
        expect(tokensText(wrapper.tokensForScreenRow(9))).toBe 'abcdefghij ? left.push(current) : '
        expect(tokensText(wrapper.tokensForScreenRow(10))).toBe 'right.push(current);'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual([[7, 0], [8, 20]])
        expect(event.newRange).toEqual([[7, 0], [10, 20]])

    describe "when buffer lines are removed", ->
      it "removes screen lines and emits a change event", ->
        buffer.change(new Range([3, 21], [7, 5]), ';')
        expect(tokensText(wrapper.tokensForScreenRow(3))).toBe '    var pivot = items;'
        expect(tokensText(wrapper.tokensForScreenRow(4))).toBe '    return '
        expect(tokensText(wrapper.tokensForScreenRow(5))).toBe 'sort(left).concat(pivot).concat(sort(right));'
        expect(tokensText(wrapper.tokensForScreenRow(6))).toBe '  };'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual([[3, 0], [11, 45]])
        expect(event.newRange).toEqual([[3, 0], [5, 45]])

  describe ".screenPositionFromBufferPosition(point, allowEOL=false)", ->
    it "translates the given buffer position to a screen position, accounting for wrapped lines", ->
      # before any wrapped lines
      expect(wrapper.screenPositionFromBufferPosition([0, 5])).toEqual([0, 5])
      expect(wrapper.screenPositionFromBufferPosition([0, 29])).toEqual([0, 29])

      # on a wrapped line
      expect(wrapper.screenPositionFromBufferPosition([3, 5])).toEqual([3, 5])
      expect(wrapper.screenPositionFromBufferPosition([3, 50])).toEqual([3, 50])
      expect(wrapper.screenPositionFromBufferPosition([3, 62])).toEqual([4, 11])

      # following a wrapped line
      expect(wrapper.screenPositionFromBufferPosition([4, 5])).toEqual([5, 5])

    describe "when allowEOL is true", ->
      it "preserves a position at the end of a wrapped screen line ", ->
        expect(wrapper.screenPositionFromBufferPosition([3, 51], true)).toEqual([3, 51])

    describe "when allowEOL is false", ->
      it "translates a position at the end of a wrapped screen line to the begining of the next screen line", ->
        expect(wrapper.screenPositionFromBufferPosition([3, 51])).toEqual([4, 0])

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

