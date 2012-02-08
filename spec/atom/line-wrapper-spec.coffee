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
    describe "when the line does not need to wrap", ->
      it "returns tokens for a single screen line", ->
        line = buffer.getLine(0)
        expect(line.length).toBeLessThan(50)
        screenLines = wrapper.wrappedLines[0].screenLines
        expect(screenLines.length).toBe 1
        expect(screenLines[0].endColumn).toBe line.length

    describe "when the line needs to wrap once", ->
      it "returns 2 screen lines, with the linebreak at the beginning of the first word that exceeds the max length", ->
        line = buffer.getLine(6)
        expect(line.length).toBeGreaterThan 50
        screenLines = wrapper.wrappedLines[6].screenLines
        expect(screenLines.length).toBe 2
        expect(screenLines[0].endColumn).toBe 45
        expect(screenLines[0].map((t) -> t.value).join('')).toBe '      current < pivot ? left.push(current) : '

        expect(screenLines[1].endColumn).toBe 65
        expect(screenLines[1].map((t) -> t.value).join('')).toBe 'right.push(current);'

    describe "when the line needs to wrap more than once", ->
      it "returns multiple screen lines", ->
        wrapper.setMaxLength(30)
        screenLines = wrapper.wrappedLines[6].screenLines

        expect(screenLines.length).toBe 3

        expect(screenLines[0].endColumn).toBe 24
        expect(_.pluck(screenLines[0], 'value').join('')).toBe '      current < pivot ? '

        expect(screenLines[1].endColumn).toBe 45
        expect(_.pluck(screenLines[1], 'value').join('')).toBe 'left.push(current) : '

        expect(screenLines[2].endColumn).toBe 65
        expect(_.pluck(screenLines[2], 'value').join('')).toBe 'right.push(current);'

  fdescribe "when the buffer changes", ->
    changeHandler = null

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

      describe "when the update causes the line to wrap once", ->

      describe "when the update causes the line to wrap multiple times", ->

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

