_ = require 'underscore'
Delta = require 'delta'
Point = require 'point'
Range = require 'range'

module.exports =
class LineMap
  constructor: ->
    @screenLines = []

  insertAtBufferRow: (bufferRow, screenLines) ->
    screenLines = [screenLines] unless _.isArray(screenLines)
    delta = new Delta
    insertIndex = 0

    for screenLine in @screenLines
      nextDelta = delta.add(screenLine.bufferDelta)
      break if nextDelta.rows > bufferRow
      delta = nextDelta
      insertIndex++

    @screenLines[insertIndex...insertIndex] = screenLines

  spliceAtBufferRow: (startRow, rowCount, screenLines) ->
    @spliceByDelta('bufferDelta', startRow, rowCount, screenLines)

  spliceAtScreenRow: (startRow, rowCount, screenLines) ->
    @spliceByDelta('screenDelta', startRow, rowCount, screenLines)

  spliceByDelta: (deltaType, startRow, rowCount, screenLines) ->
    stopRow = startRow + rowCount
    startIndex = undefined
    stopIndex = 0
    delta = new Delta

    for screenLine, i in @screenLines
      startIndex = i if delta.rows == startRow and not startIndex
      nextDelta = delta.add(screenLine[deltaType])
      break if nextDelta.rows > stopRow
      delta = nextDelta
      stopIndex++

    @screenLines[startIndex...stopIndex] = screenLines

  replaceBufferRows: (start, end, screenLines) ->
    @spliceAtBufferRow(start, end - start + 1, screenLines)

  replaceScreenRow: (row, screenLines) ->
    @replaceScreenRows(row, row, screenLines)

  replaceScreenRows: (start, end, screenLines) ->
    @spliceAtScreenRow(start, end - start + 1, screenLines)

  getScreenLines: ->
    return @screenLines

  lineForScreenRow: (row) ->
    @linesForScreenRows(row, row)[0]

  linesForScreenRows: (startRow, endRow) ->
    lastLine = null
    lines = []
    delta = new Delta

    for fragment in @screenLines
      break if delta.rows > endRow
      if delta.rows >= startRow
        if pendingFragment
          pendingFragment = pendingFragment.concat(fragment)
        else
          pendingFragment = fragment
        if pendingFragment.screenDelta.rows > 0
          lines.push pendingFragment
          pendingFragment = null
      delta = delta.add(fragment.screenDelta)
    lines

  lineForBufferRow: (row) ->
    line = null
    delta = new Delta
    for fragment in @screenLines
      break if delta.rows > row
      if delta.rows == row
        if line
          line = line.concat(fragment)
        else
          line = fragment
      delta = delta.add(fragment.bufferDelta)
    line

  bufferLineCount: ->
    delta = new Delta
    for screenLine in @screenLines
      delta = delta.add(screenLine.bufferDelta)
    delta.rows

  lineCount: ->
    delta = new Delta
    for screenLine in @screenLines
      delta = delta.add(screenLine.screenDelta)
    delta.rows

  screenPositionForBufferPosition: (bufferPosition, eagerWrap=true) ->
    bufferPosition = Point.fromObject(bufferPosition)
    bufferDelta = new Delta
    screenDelta = new Delta

    for screenLine in @screenLines
      nextDelta = bufferDelta.add(screenLine.bufferDelta)
      break if nextDelta.toPoint().greaterThan(bufferPosition)
      break if nextDelta.toPoint().isEqual(bufferPosition) and not eagerWrap
      bufferDelta = nextDelta
      screenDelta = screenDelta.add(screenLine.screenDelta)

    remainingBufferColumns = bufferPosition.column - bufferDelta.columns
    additionalScreenColumns = Math.max(0, Math.min(remainingBufferColumns, screenLine.lengthForClipping()))

    new Point(screenDelta.rows, screenDelta.columns + additionalScreenColumns)

  bufferPositionForScreenPosition: (screenPosition) ->
    screenPosition = Point.fromObject(screenPosition)
    bufferDelta = new Delta
    screenDelta = new Delta

    for screenLine in @screenLines
      nextDelta = screenDelta.add(screenLine.screenDelta)
      break if nextDelta.toPoint().greaterThan(screenPosition)
      screenDelta = nextDelta
      bufferDelta = bufferDelta.add(screenLine.bufferDelta)

    columns = bufferDelta.columns + (screenPosition.column - screenDelta.columns)
    new Point(bufferDelta.rows, columns)

  screenRangeForBufferRange: (bufferRange) ->
    start = @screenPositionForBufferPosition(bufferRange.start)
    end = @screenPositionForBufferPosition(bufferRange.end)
    new Range(start, end)

