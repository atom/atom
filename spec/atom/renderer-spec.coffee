Renderer = require 'renderer'
Buffer = require 'buffer'

describe "Renderer", ->
  [renderer, buffer, changeHandler] = []
  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    renderer = new Renderer(buffer)
    changeHandler = jasmine.createSpy 'changeHandler'
    renderer.on 'change', changeHandler

  describe "soft wrapping", ->
    beforeEach ->
      renderer.setMaxLineLength(50)

    describe "rendering of soft-wrapped lines", ->
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

  fdescribe "folding", ->
    describe "when folds are created and destroyed", ->
      describe "when a fold spans multiple lines", ->
        it "replaces the lines spanned by the fold with a single line containing a placeholder", ->
          previousLine4Text = renderer.lineForRow(4).text
          previousLine5Text = renderer.lineForRow(5).text

          fold = renderer.createFold([[4, 29], [7, 4]])

          expect(renderer.lineForRow(4).text).toBe '    while(items.length > 0) {...}'
          expect(renderer.lineForRow(5).text).toBe '    return sort(left).concat(pivot).concat(sort(right));'

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual [[4, 0], [7, 5]]
          expect(event.newRange).toEqual [[4, 0], [4, 33]]
          changeHandler.reset()

          fold.destroy()
          expect(renderer.lineForRow(4).text).toBe previousLine4Text
          expect(renderer.lineForRow(5).text).toBe previousLine5Text

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[4, 0], [4, 33]]
          expect(event.newRange).toEqual [[4, 0], [7, 5]]

      describe "when a fold spans a single line", ->
        it "renders a placeholder for the folded region, but does not skip any lines", ->
          fold = renderer.createFold([[2, 8], [2, 25]])

          [line2, line3] = renderer.linesForRows(2, 3)
          expect(line2.text).toBe '    if (...) return items;'
          expect(line3.text).toBe '    var pivot = items.shift(), current, left = [], right = [];'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.oldRange).toEqual [[2, 0], [2, 40]]
          expect(event.newRange).toEqual [[2, 0], [2, 26]]
          changeHandler.reset()

          fold.destroy()

          [line2, line3] = renderer.linesForRows(2, 3)
          expect(line2.text).toBe '    if (items.length <= 1) return items;'
          expect(line3.text).toBe '    var pivot = items.shift(), current, left = [], right = [];'

          expect(changeHandler).toHaveBeenCalled()
          [[event]] = changeHandler.argsForCall
          expect(event.newRange).toEqual [[2, 0], [2, 40]]
          expect(event.oldRange).toEqual [[2, 0], [2, 26]]
          changeHandler.reset()

      describe "when a fold is nested within another fold", ->
        it "only renders the placeholder for the inner fold when the outer fold is destroyed", ->
          outerFold = renderer.createFold([[4, 29], [8, 36]])
          innerFold = renderer.createFold([[8, 5], [8, 10]])

          [line4, line5] = renderer.linesForRows(4, 5)
          expect(line4.text).toBe '    while(items.length > 0) {...concat(sort(right));'
          expect(line5.text).toBe '  };'

          outerFold.destroy()

          [line4, line5] = renderer.linesForRows(4, 5)
          expect(line4.text).toBe '    while(items.length > 0) {'
          expect(line5.text).toBe '      current = items.shift();'
          expect(renderer.lineForRow(8).text).toBe '    r... sort(left).concat(pivot).concat(sort(right));'

        fit "allows the outer fold to start at the same location as the inner fold", ->
          renderer.createFold([[4, 29], [7, 4]])
          renderer.createFold([[4, 29], [9, 2]])
          expect(renderer.lineForRow(4).text).toBe "    while(items.length > 0) {...};"

      describe "when a fold begins on the line on which another fold ends", ->
        describe "when the second fold is created before the first fold", ->
          it "renders a placeholder for both folds on the first line of the first fold", ->
            fold1 = renderer.createFold([[7, 5], [8, 36]])
            fold2 = renderer.createFold([[4, 29], [7, 4]])

            [line4, line5] = renderer.linesForRows(4, 5)
            expect(line4.text).toBe  '    while(items.length > 0) {...}...concat(sort(right));'
            expect(line5.text).toBe '  };'

            expect(changeHandler.callCount).toBe 2
            [[event1], [event2]] = changeHandler.argsForCall
            expect(event1.oldRange).toEqual [[7, 0], [8, 56]]
            expect(event1.newRange).toEqual [[7, 0], [7, 28]]
            expect(event2.oldRange).toEqual [[4, 0], [7, 28]]
            expect(event2.newRange).toEqual [[4, 0], [4, 56]]
            changeHandler.reset()

            fold1.destroy()
            [line4, line5] = renderer.linesForRows(4, 5)
            expect(line4.text).toBe '    while(items.length > 0) {...}'
            expect(line5.text).toBe '    return sort(left).concat(pivot).concat(sort(right));'

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            expect(event.oldRange).toEqual [[4, 0], [4, 56]]
            expect(event.newRange).toEqual [[4, 0], [5, 56]]
            changeHandler.reset()

            fold2.destroy()
            [line4, line5] = renderer.linesForRows(4, 5)
            expect(line4.text).toBe '    while(items.length > 0) {'
            expect(line5.text).toBe '      current = items.shift();'

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            expect(event.oldRange).toEqual [[4, 0], [4, 33]]
            expect(event.newRange).toEqual [[4, 0], [7, 5]]

        describe "when the second fold is created after the first fold", ->
          it "renders a placeholder for both folds on the first line of the first fold", ->
            fold1 = renderer.createFold([[4, 29], [7, 4]])
            fold2 = renderer.createFold([[7, 5], [8, 36]])
            [line4, line5] = renderer.linesForRows(4, 5)
            expect(line4.text).toBe  '    while(items.length > 0) {...}...concat(sort(right));'
            expect(line5.text).toBe '  };'

            expect(changeHandler.callCount).toBe 2
            [[event1], [event2]] = changeHandler.argsForCall
            expect(event1.oldRange).toEqual [[4, 0], [7, 5]]
            expect(event1.newRange).toEqual [[4, 0], [4, 33]]
            expect(event2.oldRange).toEqual [[4, 0], [5, 56]]
            expect(event2.newRange).toEqual [[4, 0], [4, 56]]
            changeHandler.reset()

            fold1.destroy()
            [line4, line5] = renderer.linesForRows(4, 5)
            [line7] = renderer.linesForRows(7, 7)
            expect(line4.text).toBe '    while(items.length > 0) {'
            expect(line5.text).toBe '      current = items.shift();'
            expect(line7.text).toBe '    }...concat(sort(right));'

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            expect(event.oldRange).toEqual [[4, 0], [4, 56]]
            expect(event.newRange).toEqual [[4, 0], [7, 28]]
            changeHandler.reset()

            fold2.destroy()
            [line4, line5] = renderer.linesForRows(4, 5)
            expect(line4.text).toBe '    while(items.length > 0) {'
            expect(line5.text).toBe '      current = items.shift();'

            expect(changeHandler).toHaveBeenCalled()
            [event] = changeHandler.argsForCall[0]
            expect(event.oldRange).toEqual [[7, 0], [7, 28]]
            expect(event.newRange).toEqual [[7, 0], [8, 56]]

      describe "when a fold starts at the beginning of a line", ->
        it "renders a placeholder at the beginning of the line", ->
          renderer.createFold([[4, 0], [7, 4]])
          expect(renderer.lineForRow(4).text).toBe '...}'

      describe "when a fold ends at the beginning of a line", ->
        it "renders a placeholder at the beginning of the line", ->
          renderer.createFold([[4, 29], [7, 0]])
          expect(renderer.lineForRow(4).text).toBe '    while(items.length > 0) {...    }'

      describe "when a fold starts on the first line of the buffer", ->
        it "renders the first line correctly when the fold is destroyed", ->
          fold = renderer.createFold([[0, 14], [0, 27]])
          fold.destroy()
          expect(renderer.lineForRow(0).text).toBe 'var quicksort = function () {'
