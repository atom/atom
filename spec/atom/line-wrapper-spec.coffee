Buffer = require 'buffer'
LineWrapper = require 'line-wrapper'
Highlighter = require 'highlighter'
_ = require 'underscore'

fdescribe "LineWrapper", ->
  [wrapper, buffer] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    wrapper = new LineWrapper(50, new Highlighter(buffer))

  describe ".segmentsForRow(row)", ->
    describe "when the line does not need to wrap", ->
      it "returns tokens for a single segment", ->
        line = buffer.getLine(0)
        expect(line.length).toBeLessThan(50)
        segments = wrapper.segmentsForRow(0)
        expect(segments.length).toBe 1
        expect(segments[0].lastIndex).toBe line.length

    describe "when the line needs to wrap once", ->
      it "breaks the line into 2 segments at the beginning of the first word that exceeds the max length", ->
        line = buffer.getLine(6)
        expect(line.length).toBeGreaterThan 50
        segments = wrapper.segmentsForRow(6)
        expect(segments.length).toBe 2
        expect(segments[0].lastIndex).toBe 45
        expect(segments[0].map((t) -> t.value).join('')).toBe '      current < pivot ? left.push(current) : '

        expect(segments[1].lastIndex).toBe 65
        expect(segments[1].map((t) -> t.value).join('')).toBe 'right.push(current);'

    describe "when the line needs to wrap more than once", ->
      it "breaks the line into multiple segments", ->
        wrapper.setMaxLength(30)
        segments = wrapper.segmentsForRow(6)

        expect(segments.length).toBe 3

        expect(segments[0].lastIndex).toBe 24
        expect(_.pluck(segments[0], 'value').join('')).toBe '      current < pivot ? '

        expect(segments[1].lastIndex).toBe 45
        expect(_.pluck(segments[1], 'value').join('')).toBe 'left.push(current) : '

        expect(segments[2].lastIndex).toBe 65
        expect(_.pluck(segments[2], 'value').join('')).toBe 'right.push(current);'

  describe ".displayPositionFromBufferPosition(point)", ->
    it "returns the position of the indicated row and column on screen, accounting for wrapped lines", ->
      # no wrap
      expect(wrapper.displayPositionFromBufferPosition(row: 0, column: 5)).toEqual(row: 0, column: 5)

      # wrap once
      expect(wrapper.displayPositionFromBufferPosition(row: 3, column: 5)).toEqual(row: 3, column: 5)
      expect(wrapper.displayPositionFromBufferPosition(row: 3, column: 50)).toEqual(row: 3, column: 50)
      expect(wrapper.displayPositionFromBufferPosition(row: 3, column: 51)).toEqual(row: 4, column: 0)

      # following a wrap
      expect(wrapper.displayPositionFromBufferPosition(row: 4, column: 5)).toEqual(row: 5, column: 5)


