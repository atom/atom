Buffer = require 'buffer'
Higlighter = require 'highlighter'
LineFolder = require 'line-folder'
Range = require 'range'

describe "LineFolder", ->
  [buffer, folder] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    highlighter = new Higlighter(buffer)
    folder = new LineFolder(highlighter)

  describe "when there is a single fold spanning multiple lines", ->
    it "renders a placeholder on the first line of a fold, and skips subsequent lines", ->
      folder.createFold(new Range([4, 29], [7, 4]))
      [line4, line5] = folder.screenLinesForRows(4, 5)

      expect(line4.text).toBe '    while(items.length > 0) {...}'
      expect(line5.text).toBe '    return sort(left).concat(pivot).concat(sort(right));'

  describe "when there is a single fold contained on a single line", ->
    it "renders a placeholder for the folded region, but does not skip any lines", ->
      folder.createFold(new Range([2, 8], [2, 25]))
      [line2, line3] = folder.screenLinesForRows(2, 3)

      expect(line2.text).toBe '    if (...) return items;'
      expect(line3.text).toBe '    var pivot = items.shift(), current, left = [], right = [];'

  describe "when there is a nested fold on the last line of another fold", ->
    it "does not render a placeholder for the nested fold because it is inside of the other fold", ->
      folder.createFold(new Range([8, 5], [8, 10]))
      folder.createFold(new Range([4, 29], [8, 36]))
      [line4, line5] = folder.screenLinesForRows(4, 5)

      expect(line4.text).toBe '    while(items.length > 0) {...concat(sort(right));'
      expect(line5.text).toBe '  };'

  describe "when another fold begins on the last line of a fold", ->
    describe "when the second fold is created before the first fold", ->
      it "renders a placeholder for both folds on the first line of the first fold", ->
        folder.createFold(new Range([7, 5], [8, 36]))
        folder.createFold(new Range([4, 29], [7, 4]))
        [line4, line5] = folder.screenLinesForRows(4, 5)

        expect(line4.text).toBe  '    while(items.length > 0) {...}...concat(sort(right));'

    describe "when the second fold is created after the first fold", ->
      it "renders a placeholder for both folds on the first line of the first fold", ->
        folder.createFold(new Range([4, 29], [7, 4]))
        folder.createFold(new Range([7, 5], [8, 36]))
        [line4, line5] = folder.screenLinesForRows(4, 5)

        expect(line4.text).toBe  '    while(items.length > 0) {...}...concat(sort(right));'
