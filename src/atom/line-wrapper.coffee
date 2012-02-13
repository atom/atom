_ = require 'underscore'
EventEmitter = require 'event-emitter'
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
    oldRange.end.column = _.last(_.last(@wrappedLines).screenLines).text.length
    @buildWrappedLines()
    newRange = new Range
    newRange.end.row = @screenLineCount() - 1
    newRange.end.column = _.last(_.last(@wrappedLines).screenLines).text.length
    @trigger 'change', { oldRange, newRange }

  buildWrappedLines: ->
    @wrappedLines = @buildWrappedLinesForBufferRows(0, @buffer.lastRow())

  handleChange: (e) ->
    oldRange = new Range

    bufferRow = e.oldRange.start.row
    oldRange.start.row = @firstScreenRowForBufferRow(e.oldRange.start.row)
    oldRange.end.row = @lastScreenRowForBufferRow(e.oldRange.end.row)
    oldRange.end.column = _.last(@wrappedLines[e.oldRange.end.row].screenLines).text.length

    @wrappedLines[e.oldRange.start.row..e.oldRange.end.row] = @buildWrappedLinesForBufferRows(e.newRange.start.row, e.newRange.end.row)

    newRange = oldRange.copy()
    newRange.end.row = @lastScreenRowForBufferRow(e.newRange.end.row)
    newRange.end.column = _.last(@wrappedLines[e.newRange.end.row].screenLines).text.length

    @trigger 'change', { oldRange, newRange }

  firstScreenRowForBufferRow: (bufferRow) ->
    @screenPositionFromBufferPosition([bufferRow, 0]).row

  lastScreenRowForBufferRow: (bufferRow) ->
    startRow = @screenPositionFromBufferPosition([bufferRow, 0]).row
    startRow + (@wrappedLines[bufferRow].screenLines.length - 1)

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
    row = 0
    for wrappedLine in @wrappedLines[0...bufferPosition.row]
      row += wrappedLine.screenLines.length

    column = bufferPosition.column

    screenLines = @wrappedLines[bufferPosition.row].screenLines
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
    bufferRow = 0
    currentScreenRow = 0
    for wrappedLine in @wrappedLines
      for screenLine in wrappedLine.screenLines
        if currentScreenRow == screenPosition.row
          return new Point(bufferRow, screenLine.startColumn + screenPosition.column)
        currentScreenRow++
      bufferRow++

  tokensForScreenRow: (screenRow) ->
    currentScreenRow = 0
    for wrappedLine in @wrappedLines
      for screenLine in wrappedLine.screenLines
        return screenLine.tokens if currentScreenRow == screenRow
        currentScreenRow++

  screenLineCount: ->
    count = 0
    for wrappedLine, i in @wrappedLines
      count += wrappedLine.screenLines.length
    count

_.extend(LineWrapper.prototype, EventEmitter)
