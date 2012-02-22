_ = require 'underscore'
EventEmitter = require 'event-emitter'
SpanIndex = require 'span-index'
LineMap = require 'line-map'
Point = require 'point'
Range = require 'range'
Delta = require 'delta'

module.exports =
class LineWrapper
  constructor: (@maxLength, @highlighter) ->
    @buffer = @highlighter.buffer
    @buildWrappedLines()
    @highlighter.on 'change', (e) => @handleChange(e)

  setMaxLength: (@maxLength) ->
    oldRange = new Range
    oldRange.end.row = @screenLineCount() - 1
    oldRange.end.column = @lineMap.lineForScreenRow(oldRange.end.row).text.length
    @buildWrappedLines()
    newRange = new Range
    newRange.end.row = @screenLineCount() - 1
    newRange.end.column = @lineMap.lineForScreenRow(newRange.end.row).text.length
    @trigger 'change', { oldRange, newRange }

  getSpans: (wrappedLines) ->
    wrappedLines.map (line) -> line.screenLines.length

  unpackWrappedLines: (wrappedLines) ->
    _.flatten(_.pluck(wrappedLines, 'screenLines'))

  buildWrappedLines: ->
    @lineMap = new LineMap
    wrappedLines = @buildWrappedLinesForBufferRows(0, @buffer.lastRow())
    @lineMap.insertAtBufferRow 0, @unpackWrappedLines(wrappedLines)

  handleChange: (e) ->
    oldScreenRange = @lineMap.screenRangeForBufferRange(@expandRangeToLineEnds(e.oldRange))

    { start, end } = e.oldRange
    wrappedLines = @buildWrappedLinesForBufferRows(e.newRange.start.row, e.newRange.end.row)
    @lineMap.replaceBufferRows start.row, end.row, @unpackWrappedLines(wrappedLines)

    newScreenRange = @lineMap.screenRangeForBufferRange(@expandRangeToLineEnds(e.newRange))

    @trigger 'change', { oldRange: oldScreenRange, newRange: newScreenRange }

  expandRangeToLineEnds: (bufferRange) ->
    { start, end } = bufferRange
    new Range([start.row, 0], [end.row, @lineMap.lineForBufferRow(end.row).text.length])

  buildWrappedLinesForBufferRows: (start, end) ->
    for row in [start..end]
      @buildWrappedLineForBufferRow(row)

  buildWrappedLineForBufferRow: (bufferRow) ->
    { screenLines: @wrapScreenLine(@highlighter.lineFragmentForRow(bufferRow)) }

  wrapScreenLine: (screenLine, startColumn=0) ->
    screenLines = []
    splitColumn = @findSplitColumn(screenLine.text)

    if splitColumn == 0 or splitColumn == screenLine.text.length
      screenLines.push screenLine
      endColumn = startColumn + screenLine.text.length
    else
      [leftHalf, rightHalf] = screenLine.splitAt(splitColumn)
      leftHalf.screenDelta = new Delta(1, 0)
      screenLines.push leftHalf
      endColumn = startColumn + leftHalf.text.length
      screenLines.push @wrapScreenLine(rightHalf, endColumn)...

    _.extend(screenLines[0], {startColumn, endColumn})
    screenLines

  findSplitColumn: (line) ->
    return line.length unless line.length > @maxLength

    if /\s/.test(line[@maxLength])
      # search forward for the start of a word past the boundary
      for column in [@maxLength..line.length]
        return column if /\S/.test(line[column])
      return line.length
    else
      # search backward for the start of the word on the boundary
      for column in [@maxLength..0]
        return column + 1 if /\s/.test(line[column])
      return @maxLength

  screenRangeForBufferRange: (bufferRange) ->
    @lineMap.screenRangeForBufferRange(bufferRange)

  screenPositionForBufferPosition: (bufferPosition, eagerWrap=true) ->
    @lineMap.screenPositionForBufferPosition(bufferPosition, eagerWrap)

  bufferPositionForScreenPosition: (screenPosition) ->
    @lineMap.bufferPositionForScreenPosition(screenPosition)

  screenLineForRow: (screenRow) ->
    @screenLinesForRows(screenRow, screenRow)[0]

  screenLinesForRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

  screenLines: ->
    @screenLinesForRows(0, @screenLineCount() - 1)

  screenLineCount: ->
    @lineMap.screenLineCount()

_.extend(LineWrapper.prototype, EventEmitter)
