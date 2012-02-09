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

      expect(line1.endColumn).toBe 24
      expect(tokensText(line1)).toBe '      current < pivot ? '

      expect(line2.endColumn).toBe 45
      expect(tokensText(line2)).toBe 'left.push(current) : '

      expect(line3.endColumn).toBe 65
      expect(tokensText(line3)).toBe 'right.push(current);'

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
        xit "updates tokens for the corresponding screen lines and emits a change event", ->
          console.log '!!!!!!!!!!!!!!!!!!!!!!!!!!!'
          buffer.insert([2, 4], ["/*",longText, longText, longText, longText, "*/"].join(' '))
          expect(tokensText(wrapper.tokensForScreenRow(2))).toBe '    0123456789ABCDEF 0123456789ABCDEF '
          # expect(tokensText(wrapper.tokensForScreenRow(3))).toBe '0123456789ABCDEF 0123456789ABCDEF if (items.length '
          # expect(tokensText(wrapper.tokensForScreenRow(4))).toBe '<= 1) return items;'
          # expect(tokensText(wrapper.tokensForScreenRow(3))).toBe 'items;'
          # expect(tokensText(wrapper.tokensForScreenRow(4))).toBe '    var pivot = items.shift(), current, left = [], '

          # expect(changeHandler).toHaveBeenCalled()
          # [event] = changeHandler.argsForCall[0]
          # expect(event.oldRange).toEqual(new Range([2, 4], [2, 4]))
          # expect(event.newRange).toEqual(new Range([2, 4], [3, 6]))

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
    beforeEach ->
      wrapper.setMaxLength(10)

    describe "when the text length of the given tokens is less then the max line length", ->
      it "only returns 1 screen line", ->
        screenLines = wrapper.splitTokens [{value: '12345'}, {value: '12345'}]
        expect(screenLines.length).toBe 1
        [line] = screenLines
        expect(line.startColumn).toBe 0
        expect(line.endColumn).toBe 10
        expect(line.textLength).toBe 10

    describe "when the text length of the given tokens exceeds the max line length", ->
      describe "when the exceeding token begins at the max line length", ->
        describe "when the token has no whitespace", ->
          it "places exceeding token on the next screen line", ->
            screenLines = wrapper.splitTokens([{value: '12345'}, {value: '12345'}, {value: 'abcde'}])
            expect(screenLines.length).toBe 2
            [line1, line2] = screenLines
            expect(line1).toEqual [{value: '12345'}, {value: '12345'}]
            expect(line2).toEqual [{value: 'abcde'}]

            expect(line1.startColumn).toBe 0
            expect(line1.endColumn).toBe 10
            expect(line1.textLength).toBe 10
            expect(line2.startColumn).toBe 10
            expect(line2.endColumn).toBe 15
            expect(line2.textLength).toBe 5

        describe "when token has leading whitespace", ->
          it "splits the token in half and places the non-whitespace portion on the next line", ->
            screenLines = wrapper.splitTokens([{value: '12345'}, {value: '12345'}, {value: '   abcde', type: 'foo'}, {value: 'ghi'}])
            expect(screenLines.length).toBe 2
            [line1, line2] = screenLines
            expect(line1).toEqual [{value: '12345'}, {value: '12345'}, {value: '   ', type: 'foo'}]
            expect(line2).toEqual [{value: 'abcde', type: 'foo'}, {value: 'ghi'}]

            expect(line1.startColumn).toBe 0
            expect(line1.endColumn).toBe 13
            expect(line1.textLength).toBe 13
            expect(line2.startColumn).toBe 13
            expect(line2.endColumn).toBe 21
            expect(line2.textLength).toBe 8

        describe "when the exceeding token is only whitespace", ->
          it "keeps the token on the first line and places the following token on the next line", ->
            screenLines = wrapper.splitTokens([{value: '12345'}, {value: '12345'}, {value: '   '}, {value: 'ghi'}])
            expect(screenLines.length).toBe 2
            [line1, line2] = screenLines
            expect(line1).toEqual [{value: '12345'}, {value: '12345'}, {value: '   '}]
            expect(line2).toEqual [{value: 'ghi'}]

      describe "when the exceeding token straddles the max line length", ->
        describe "when the token has no whitespace", ->
          describe "when the token's length does not exceed the max length", ->
            it "places the entire token on the next line", ->
              screenLines = wrapper.splitTokens([{value: '12345'}, {value: '123'}, {value: 'abcde'}])
              [line1, line2] = screenLines
              expect(screenLines.length).toBe 2
              expect(line1).toEqual [{value: '12345'}, {value: '123'}]
              expect(line2).toEqual [{value: 'abcde'}]

          describe "when the token's length exceeds the max length", ->
            it "splits the token arbitrarily at max length because it won't fit on the next line anyway", ->
              screenLines = wrapper.splitTokens([{value: '12345'}, {value: '123'}, {value: 'abcdefghijk', type: 'foo'}])
              expect(screenLines.length).toBe 2
              [line1, line2] = screenLines
              expect(line1).toEqual [{value: '12345'}, {value: '123'}, {value: 'ab', type: 'foo'}]
              expect(line2).toEqual [{value: 'cdefghijk', type: 'foo'}]

        describe "when the token has leading whitespace", ->
          it "splits the token in half and places the non-whitespace portion on the next line", ->
            screenLines = wrapper.splitTokens([{value: '12345'}, {value: '123'}, {value: '   abcde', type: 'foo'}, {value: 'ghi'}])
            expect(screenLines.length).toBe 2
            [line1, line2] = screenLines
            expect(line1).toEqual [{value: '12345'}, {value: '123'}, {value: '   ', type: 'foo'}]
            expect(line2).toEqual [{value: 'abcde', type: 'foo'}, {value: 'ghi'}]

        describe "when the token has trailing whitespace", ->
          it "places the entire token on the next lien", ->
            screenLines = wrapper.splitTokens([{value: '12345'}, {value: '123'}, {value: 'abcde   '}])
            expect(screenLines.length).toBe 2
            [line1, line2] = screenLines
            expect(line1).toEqual [{value: '12345'}, {value: '123'}]
            expect(line2).toEqual [{value: 'abcde   '}]

        describe "when the token has interstitial whitespace preceding the max line length", ->
          it "splits the token at the first word boundary following the max line length", ->
            screenLines = wrapper.splitTokens([{value: '123'}, {value: '456'}, {value: 'a b   de', type: 'foo'}, {value: 'ghi'}])
            expect(screenLines.length).toBe 2
            [line1, line2] = screenLines
            expect(line1).toEqual [{value: '123'}, {value: '456'}, {value: 'a b   ', type: 'foo'}]
            expect(line2).toEqual [{value: 'de', type: 'foo'}, {value: 'ghi'}]

        describe "when the exceeding token is only whitespace", ->
          it "keeps the token on the first line and places the following token on the next line", ->
            screenLines = wrapper.splitTokens([{value: '12345'}, {value: '123'}, {value: '   '}, {value: 'ghi'}])
            expect(screenLines.length).toBe 2
            [line1, line2] = screenLines
            expect(line1).toEqual [{value: '12345'}, {value: '123'}, {value: '   '}]
            expect(line2).toEqual [{value: 'ghi'}]

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

