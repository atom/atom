Buffer = require 'buffer'
Highlighter = require 'highlighter'
LineCommenter = require 'line-commenter'

describe "LineCommenter", ->
  [buffer, lineCommenter] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    highlighter = new Highlighter(buffer)
    lineCommenter = new LineCommenter(highlighter)

  fdescribe "toggleLineCommentsInRange", ->
    lineCommenter.toggleLineCommentsInRange([[4, 5], [7, 8]])
    expect(buffer.lineForRow(4)).toBe "//    while(items.length > 0) {"
    expect(buffer.lineForRow(5)).toBe "//      current = items.shift();"
    expect(buffer.lineForRow(6)).toBe "//      current < pivot ? left.push(current) : right.push(current);"
    expect(buffer.lineForRow(7)).toBe "//    }"
