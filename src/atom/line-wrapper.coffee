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
    oldRange.end.column = _.last(@index.last().screenLines).text.length
    @buildWrappedLines()
    newRange = new Range
    newRange.end.row = @screenLineCount() - 1
    newRange.end.column = _.last(@index.last().screenLines).text.length
    @trigger 'change', { oldRange, newRange }

  getSpans: (wrappedLines) ->
    wrappedLines.map (line) -> line.screenLines.length

  unpackWrappedLines: (wrappedLines) ->
    _.flatten(_.pluck(wrappedLines, 'screenLines'))

  buildWrappedLines: ->
    @index = new SpanIndex
    @lineMap = new LineMap
    wrappedLines = @buildWrappedLinesForBufferRows(0, @buffer.lastRow())
    @index.insert 0, @getSpans(wrappedLines), wrappedLines
    @lineMap.insertAtBufferRow 0, @unpackWrappedLines(wrappedLines)

  handleChange: (e) ->
    oldRange = new Range

    bufferRow = e.oldRange.start.row
    oldRange.start.row = @firstScreenRowForBufferRow(e.oldRange.start.row)
    oldRange.end.row = @lastScreenRowForBufferRow(e.oldRange.end.row)
    oldRange.end.column = _.last(@index.at(e.oldRange.end.row).screenLines).text.length

    { start, end } = e.oldRange
    wrappedLines = @buildWrappedLinesForBufferRows(e.newRange.start.row, e.newRange.end.row)
    @index.splice start.row, end.row, @getSpans(wrappedLines), wrappedLines
    @lineMap.replaceBufferRows start.row, end.row, @unpackWrappedLines(wrappedLines)

    newRange = oldRange.copy()
    newRange.end.row = @lastScreenRowForBufferRow(e.newRange.end.row)
    newRange.end.column = _.last(@index.at(e.newRange.end.row).screenLines).text.length

    @trigger 'change', { oldRange, newRange }

  firstScreenRowForBufferRow: (bufferRow) ->
    @screenPositionForBufferPosition([bufferRow, 0]).row

  lastScreenRowForBufferRow: (bufferRow) ->
    startRow = @screenPositionForBufferPosition([bufferRow, 0]).row
    startRow + (@index.at(bufferRow).screenLines.length - 1)

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

  screenRangeFromBufferRange: (bufferRange) ->
    start = @screenPositionForBufferPosition(bufferRange.start, false)
    end = @screenPositionForBufferPosition(bufferRange.end, false)
    new Range(start,end)

  screenPositionForBufferPosition: (bufferPosition, eagerWrap=true) ->
    return @lineMap.screenPositionForBufferPosition(bufferPosition, eagerWrap)

  bufferPositionFromScreenPosition: (screenPosition) ->
    screenPosition = Point.fromObject(screenPosition)
    { index, offset } = @index.indexForSpan(screenPosition.row)
    row = index
    column = @index.at(row).screenLines[offset].startColumn + screenPosition.column
    new Point(row, column)

  screenLineForRow: (screenRow) ->
    @screenLinesForRows(screenRow, screenRow)[0]

  screenLinesForRows: (startRow, endRow) ->
    screenLines = []

    { values, startOffset, endOffset } = @index.sliceBySpan(startRow, endRow)

    screenLines.push(values[0].screenLines[startOffset..-1]...)
    for wrappedLine in values[1...-1]
      screenLines.push(wrappedLine.screenLines...)
    screenLines.push(_.last(values).screenLines[0..endOffset]...)
    screenLines

  screenLines: ->
    @screenLinesForRows(0, @screenLineCount() - 1)

  screenLineCount: ->
    @lineMap.screenLineCount()

_.extend(LineWrapper.prototype, EventEmitter)
