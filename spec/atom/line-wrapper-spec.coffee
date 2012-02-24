Buffer = require 'buffer'
LineWrapper = require 'line-wrapper'
Highlighter = require 'highlighter'
Range = require 'range'
ScreenLineFragment = require 'screen-line-fragment'
_ = require 'underscore'

describe "LineWrapper", ->
  [wrapper, buffer, changeHandler] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    wrapper = new LineWrapper(50, new Highlighter(buffer))
    changeHandler = jasmine.createSpy('changeHandler')
    wrapper.on 'change', changeHandler

  describe ".lineForScreenRow(row)", ->
    it "returns tokens for the line fragment corresponding to the given screen row", ->
      expect(tokensText wrapper.lineForScreenRow(3).tokens).toEqual('    var pivot = items.shift(), current, left = [], ')
      expect(tokensText wrapper.lineForScreenRow(4).tokens).toEqual('right = [];')
      expect(tokensText wrapper.lineForScreenRow(5).tokens).toEqual('    while(items.length > 0) {')

  describe ".lineCount()", ->
    it "returns the total number of screen lines", ->
      expect(wrapper.lineCount()).toBe 16

  describe "when the buffer changes", ->
    describe "when a buffer line is updated", ->
      describe "when the number of screen lines remains the same for the changed buffer line", ->
        it "re-wraps the existing lines and emits a change event for all its screen lines", ->
          buffer.insert([6, 28], '1234567')
          expect(wrapper.lineForScreenRow(7).text).toBe '      current < pivot ? left1234567.push(current) '
          expect(wrapper.lineForScreenRow(8).text).toBe ': right.push(current);'
          expect(wrapper.lineForScreenRow(9).text).toBe '    }'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[7, 0], [8, 20]])
          expect(event.newRange).toEqual([[7, 0], [8, 22]])

      describe "when the number of screen lines increases for the changed buffer line", ->
        it "re-wraps and adds an additional screen line and emits a change event for all screen lines", ->
          buffer.insert([6, 28], '1234567890')
          expect(wrapper.lineForScreenRow(7).text).toBe '      current < pivot ? '
          expect(wrapper.lineForScreenRow(8).text).toBe 'left1234567890.push(current) : '
          expect(wrapper.lineForScreenRow(9).text).toBe 'right.push(current);'
          expect(wrapper.lineForScreenRow(10).text).toBe '    }'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[7, 0], [8, 20]])
          expect(event.newRange).toEqual([[7, 0], [9, 20]])

      describe "when the number of screen lines decreases for the changed buffer line", ->
        it "re-wraps and removes a screen line and emits a change event for all screen lines", ->
          buffer.change(new Range([6, 24], [6, 42]), '')
          expect(wrapper.lineForScreenRow(7).text).toBe '      current < pivot ?  : right.push(current);'
          expect(wrapper.lineForScreenRow(8).text).toBe '    }'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual([[7, 0], [8, 20]])
          expect(event.newRange).toEqual([[7, 0], [7, 47]])

    describe "when buffer lines are inserted", ->
      it "re-wraps existing and new screen lines and emits a change event", ->
        buffer.insert([6, 21], '1234567890 abcdefghij 1234567890\nabcdefghij')
        expect(wrapper.lineForScreenRow(7).text).toBe '      current < pivot1234567890 abcdefghij '
        expect(wrapper.lineForScreenRow(8).text).toBe '1234567890'
        expect(wrapper.lineForScreenRow(9).text).toBe 'abcdefghij ? left.push(current) : '
        expect(wrapper.lineForScreenRow(10).text).toBe 'right.push(current);'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual([[7, 0], [8, 20]])
        expect(event.newRange).toEqual([[7, 0], [10, 20]])

    describe "when buffer lines are removed", ->
      it "removes screen lines and emits a change event", ->
        buffer.change(new Range([3, 21], [7, 5]), ';')
        expect(wrapper.lineForScreenRow(3).text).toBe '    var pivot = items;'
        expect(wrapper.lineForScreenRow(4).text).toBe '    return '
        expect(wrapper.lineForScreenRow(5).text).toBe 'sort(left).concat(pivot).concat(sort(right));'
        expect(wrapper.lineForScreenRow(6).text).toBe '  };'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual([[3, 0], [11, 45]])
        expect(event.newRange).toEqual([[3, 0], [5, 45]])

  describe ".setMaxLength(length)", ->
    it "changes the length at which lines are wrapped and emits a change event for all screen lines", ->
      wrapper.setMaxLength(40)
      expect(tokensText wrapper.lineForScreenRow(4).tokens).toBe 'left = [], right = [];'
      expect(tokensText wrapper.lineForScreenRow(5).tokens).toBe '    while(items.length > 0) {'
      expect(tokensText wrapper.lineForScreenRow(12).tokens).toBe 'sort(left).concat(pivot).concat(sort(rig'

      expect(changeHandler).toHaveBeenCalled()
      [event] = changeHandler.argsForCall[0]
      expect(event.oldRange).toEqual([[0, 0], [15, 2]])
      expect(event.newRange).toEqual([[0, 0], [18, 2]])

  describe ".screenPositionForBufferPosition(point, eagerWrap=true)", ->
    it "translates the given buffer position to a screen position, accounting for wrapped lines", ->
      # before any wrapped lines
      expect(wrapper.screenPositionForBufferPosition([0, 5])).toEqual([0, 5])
      expect(wrapper.screenPositionForBufferPosition([0, 29])).toEqual([0, 29])

      # on a wrapped line
      expect(wrapper.screenPositionForBufferPosition([3, 5])).toEqual([3, 5])
      expect(wrapper.screenPositionForBufferPosition([3, 50])).toEqual([3, 50])
      expect(wrapper.screenPositionForBufferPosition([3, 62])).toEqual([4, 11])

      # following a wrapped line
      expect(wrapper.screenPositionForBufferPosition([4, 5])).toEqual([5, 5])

    describe "when eagerWrap is false", ->
      it "preserves a position at the end of a wrapped screen line ", ->
        expect(wrapper.screenPositionForBufferPosition([3, 51], false)).toEqual([3, 51])

    describe "when eagerWrap is true", ->
      it "translates a position at the end of a wrapped screen line to the begining of the next screen line", ->
        expect(wrapper.screenPositionForBufferPosition([3, 51], true)).toEqual([4, 0])

  describe ".bufferPositionForScreenPosition(point)", ->
    it "translates the given screen position to a buffer position, account for wrapped lines", ->
      # before any wrapped lines
      expect(wrapper.bufferPositionForScreenPosition([0, 5])).toEqual([0, 5])

      # on a wrapped line
      expect(wrapper.bufferPositionForScreenPosition([3, 5])).toEqual([3, 5])
      expect(wrapper.bufferPositionForScreenPosition([4, 0])).toEqual([3, 51])
      expect(wrapper.bufferPositionForScreenPosition([4, 5])).toEqual([3, 56])

      # following a wrapped line
      expect(wrapper.bufferPositionForScreenPosition([5, 5])).toEqual([4, 5])

  describe ".wrapScreenLine(screenLine)", ->
    makeTokens = (tokenValues...) ->
      tokenValues.map (value) -> { value, type: 'foo' }

    makeScreenLine = (tokenValues...) ->
      tokens = makeTokens(tokenValues...)
      text = tokenValues.join('')
      new ScreenLineFragment(tokens, text, [1, 0], [1, 0])

    beforeEach ->
      wrapper.setMaxLength(10)

    describe "when the buffer line is shorter than max length", ->
      it "does not split the line", ->
        screenLines = wrapper.wrapScreenLine(makeScreenLine 'abc', 'def')
        expect(screenLines.length).toBe 1
        expect(screenLines[0].tokens).toEqual(makeTokens 'abc', 'def')

        [line1] = screenLines
        expect(line1.startColumn).toBe 0
        expect(line1.endColumn).toBe 6
        expect(line1.text.length).toBe 6
        expect(line1.screenDelta).toEqual [1, 0]
        expect(line1.bufferDelta).toEqual [1, 0]

    describe "when the buffer line is empty", ->
      it "returns a single empty screen line", ->
        screenLines = wrapper.wrapScreenLine(makeScreenLine())
        expect(screenLines.length).toBe 1
        [screenLine] = screenLines
        expect(screenLine.tokens).toEqual []
        expect(screenLine.screenDelta).toEqual [1, 0]
        expect(screenLine.bufferDelta).toEqual [1, 0]

    describe "when there is a non-whitespace character at the max-length boundary", ->
      describe "when there is whitespace before the max-length boundary", ->
        it "splits the line at the start of the first word before the boundary", ->
          screenLines = wrapper.wrapScreenLine(makeScreenLine '12 ', '45 ', ' 89A', 'BC')
          expect(screenLines.length).toBe 2
          [line1, line2] = screenLines
          expect(line1.tokens).toEqual(makeTokens '12 ', '45 ', ' ')
          expect(line2.tokens).toEqual(makeTokens '89A', 'BC')

          expect(line1.startColumn).toBe 0
          expect(line1.endColumn).toBe 7
          expect(line1.text.length).toBe 7
          expect(line1.screenDelta).toEqual [1, 0]
          expect(line1.bufferDelta).toEqual [0, 7]

          expect(line2.startColumn).toBe 7
          expect(line2.endColumn).toBe 12
          expect(line2.text.length).toBe 5
          expect(line2.screenDelta).toEqual [1, 0]
          expect(line2.bufferDelta).toEqual [1, 0]

      describe "when there is no whitespace before the max-length boundary", ->
        it "splits the line at the boundary, because there's no 'good' place to split it", ->
          screenLines = wrapper.wrapScreenLine(makeScreenLine '123', '456', '789AB', 'CD')
          expect(screenLines.length).toBe 2
          [line1, line2] = screenLines
          expect(line1.tokens).toEqual(makeTokens '123', '456', '789A')
          expect(line2.tokens).toEqual(makeTokens 'B', 'CD')

          expect(line1.startColumn).toBe 0
          expect(line1.endColumn).toBe 10
          expect(line1.text.length).toBe 10

          expect(line2.startColumn).toBe 10
          expect(line2.endColumn).toBe 13
          expect(line2.text.length).toBe 3

    describe "when there is a whitespace character at the max-length boundary", ->
      it "splits the line at the start of the first word beyond the boundary", ->
          screenLines = wrapper.wrapScreenLine(makeScreenLine '12 ', '45 ', ' 89  C', 'DE')
          expect(screenLines.length).toBe 2
          [line1, line2] = screenLines
          expect(line1.tokens).toEqual(makeTokens '12 ', '45 ', ' 89  ')
          expect(line2.tokens).toEqual(makeTokens 'C', 'DE')

          expect(line1.startColumn).toBe 0
          expect(line1.endColumn).toBe 11
          expect(line1.text.length).toBe 11

          expect(line2.startColumn).toBe 11
          expect(line2.endColumn).toBe 14
          expect(line2.text.length).toBe 3

