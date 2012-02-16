_ = require 'underscore'
EventEmitter = require 'event-emitter'
SpanIndex = require 'span-index'
Point = require 'point'
Range = require 'range'

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

  buildWrappedLines: ->
    @index = new SpanIndex
    wrappedLines = @buildWrappedLinesForBufferRows(0, @buffer.lastRow())
    @index.insert 0, @getSpans(wrappedLines), wrappedLines

  handleChange: (e) ->
    oldRange = new Range

    bufferRow = e.oldRange.start.row
    oldRange.start.row = @firstScreenRowForBufferRow(e.oldRange.start.row)
    oldRange.end.row = @lastScreenRowForBufferRow(e.oldRange.end.row)
    oldRange.end.column = _.last(@index.at(e.oldRange.end.row).screenLines).text.length

    { start, end } = e.oldRange
    wrappedLines = @buildWrappedLinesForBufferRows(e.newRange.start.row, e.newRange.end.row)
    @index.splice start.row, end.row, @getSpans(wrappedLines), wrappedLines

    newRange = oldRange.copy()
    newRange.end.row = @lastScreenRowForBufferRow(e.newRange.end.row)
    newRange.end.column = _.last(@index.at(e.newRange.end.row).screenLines).text.length

    @trigger 'change', { oldRange, newRange }

  firstScreenRowForBufferRow: (bufferRow) ->
    @screenPositionFromBufferPosition([bufferRow, 0]).row

  lastScreenRowForBufferRow: (bufferRow) ->
    startRow = @screenPositionFromBufferPosition([bufferRow, 0]).row
    startRow + (@index.at(bufferRow).screenLines.length - 1)

  buildWrappedLinesForBufferRows: (start, end) ->
    for row in [start..end]
      @buildWrappedLineForBufferRow(row)

  buildWrappedLineForBufferRow: (bufferRow) ->
    { screenLines: @wrapScreenLine(@highlighter.screenLineForRow(bufferRow)) }

  wrapScreenLine: (screenLine, startColumn=0) ->
    [leftHalf, rightHalf] = screenLine.splitAt(@findSplitColumn(screenLine.text))
    endColumn = startColumn + leftHalf.text.length
    _.extend(leftHalf, {startColumn, endColumn})
    if rightHalf
      [leftHalf].concat @wrapScreenLine(rightHalf, endColumn)
    else
      [leftHalf]

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
    start = @screenPositionFromBufferPosition(bufferRange.start, true)
    end = @screenPositionFromBufferPosition(bufferRange.end, true)
    new Range(start,end)

  screenPositionFromBufferPosition: (bufferPosition, allowEOL=false) ->
    bufferPosition = Point.fromObject(bufferPosition)
    screenLines = @index.at(bufferPosition.row).screenLines
    row = @index.spanForIndex(bufferPosition.row) - screenLines.length
    column = bufferPosition.column

    for screenLine, index in screenLines
      break if index == screenLines.length - 1
      if allowEOL
        break if screenLine.endColumn >= bufferPosition.column
      else
        break if screenLine.endColumn > bufferPosition.column

      column -= screenLine.text.length
      row++

    new Point(row, column)

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
    @index.lengthBySpan()

_.extend(LineWrapper.prototype, EventEmitter)
