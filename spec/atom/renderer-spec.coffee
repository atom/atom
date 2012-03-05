Renderer = require 'renderer'
Buffer = require 'buffer'

describe "Renderer", ->
  [renderer, buffer] = []
  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    renderer = new Renderer(buffer)

  describe "line rendering", ->
    fdescribe "soft wrapping", ->
      beforeEach ->
        renderer.setMaxLineLength(50)

      describe "when the line is shorter than the max line length", ->
        it "renders the line unchanged", ->
          expect(renderer.lineForRow(0).text).toBe buffer.lineForRow(0)

      describe "when the line is empty", ->
        it "renders the empty line", ->
          expect(renderer.lineForRow(13).text).toBe ''

      describe "when there is a non-whitespace character at the max length boundary", ->
        describe "when there is whitespace before the boundary", ->
          it "wraps the line at the end of the first whitespace preceding the boundary", ->
            expect(renderer.lineForRow(10).text).toBe '    return '
            expect(renderer.lineForRow(11).text).toBe 'sort(left).concat(pivot).concat(sort(right));'

        describe "when there is no whitespace before the boundary", ->
          it "wraps the line exactly at the boundary since there's no more graceful place to wrap it", ->
            buffer.change([[0, 0], [1, 0]], 'abcdefghijklmnopqrstuvwxyz\n')
            renderer.setMaxLineLength(10)
            expect(renderer.lineForRow(0).text).toBe 'abcdefghij'
            expect(renderer.lineForRow(1).text).toBe 'klmnopqrst'
            expect(renderer.lineForRow(2).text).toBe 'uvwxyz'

      describe "when there is a whitespace character at the max length boundary", ->
        it "wraps the line at the first non-whitespace character following the boundary", ->
          expect(renderer.lineForRow(3).text).toBe '    var pivot = items.shift(), current, left = [], '
          expect(renderer.lineForRow(4).text).toBe 'right = [];'

      describe "when there is a fold placeholder straddling the max length boundary", ->

    describe "folding", ->
      describe "when a fold spans multiple lines", ->

      describe "when a fold spans a single line", ->

      describe "when a fold is nested within another fold", ->

      describe "when a fold begins on the line on which another fold ends", ->

      describe "when a fold starts at the beginning of a line", ->

      describe "when a fold ends at the beginning of a line", ->

      describe "when a fold starts on the first line of the buffer", ->

    describe "soft wrapping combined with folding", ->
      describe "when a line with a fold placeholder is longer than the max line length", ->









