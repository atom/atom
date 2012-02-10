Buffer = require 'buffer'
LineWrapper = require 'line-wrapper'
Highlighter = require 'highlighter'
Range = require 'range'
_ = require 'underscore'

describe "LineWrapper", ->
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
    text10 = '0123456789'
    text60 = '0123456789 123456789 123456789 123456789 123456789 123456789'

    beforeEach ->
      changeHandler = jasmine.createSpy('changeHandler')
      wrapper.on 'change', changeHandler

    fdescribe "when a single buffer line is updated", ->
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

    describe "when buffer lines are removed", ->

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
      describe "when the old text spans multiple screen lines", ->
        describe "when the new text spans fewer screen lines than the old text", ->
          it "updates tokens for the corresponding screen lines and emits a change event", ->
            wrapper.setMaxLength(15)

            range = new Range([3, 8], [3, 47])
            buffer.change(range, "a")
            expect(tokensText(wrapper.tokensForScreenRow(9))).toBe '    var a [], '
            expect(tokensText(wrapper.tokensForScreenRow(10))).toBe 'right = [];'
            expect(tokensText(wrapper.tokensForScreenRow(11))).toBe '    '

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            expect(event.oldRange).toEqual [[9, 8], [11, 16]]
            expect(event.newRange).toEqual [[9, 8], [9, 9]]

        describe "when the new text spans as many screen lines than the old text", ->
          it "updates tokens for the corresponding screen lines and emits a change event", ->
            range = new Range([3, 40], [3, 57])
            buffer.change(range, text10)
            expect(tokensText(wrapper.tokensForScreenRow(3))).toBe '    var pivot = items.shift(), current, '
            expect(tokensText(wrapper.tokensForScreenRow(4))).toBe '0123456789= [];'
            expect(tokensText(wrapper.tokensForScreenRow(5))).toBe '    while(items.length > 0) {'

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            expect(event.oldRange).toEqual [[3, 40], [4, 6]]
            expect(event.newRange).toEqual [[3, 40], [4, 10]]

        describe "when the new text spans more screen lines than the old text", ->
          it "updates tokens for the corresponding screen lines and emits a change event", ->
            range = new Range([3, 40], [3, 57])
            buffer.change(range, text60)
            expect(tokensText(wrapper.tokensForScreenRow(3))).toBe '    var pivot = items.shift(), current, 0123456789 '
            expect(tokensText(wrapper.tokensForScreenRow(4))).toBe '123456789 123456789 123456789 123456789 123456789= '
            expect(tokensText(wrapper.tokensForScreenRow(5))).toBe '[];'
            expect(tokensText(wrapper.tokensForScreenRow(6))).toBe '    while(items.length > 0) {'

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            expect(event.oldRange).toEqual [[3, 40], [4, 6]]
            expect(event.newRange).toEqual [[3, 40], [5, 3]]

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

