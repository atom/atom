Buffer = require 'buffer'
Higlighter = require 'highlighter'
LineFolder = require 'line-folder'
Range = require 'range'

fdescribe "LineFolder", ->
  [buffer, folder] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    highlighter = new Higlighter(buffer)
    folder = new LineFolder(highlighter)

  describe ".screenLineForRow(row)", ->
    beforeEach ->
      folder.createFold(new Range([4, 29], [7, 4]))

    it "renders a placeholder on the first line of a fold, and skips subsequent lines", ->
      line4 = folder.screenLineForRow(4)
      line5 = folder.screenLineForRow(5)
      expect(line4.text).toBe '    while(items.length > 0) {...}'
      expect(line5.text).toBe '    return sort(left).concat(pivot).concat(sort(right));'

