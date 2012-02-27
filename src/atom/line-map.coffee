_ = require 'underscore'
Point = require 'point'
Range = require 'range'

module.exports =
class LineMap
  constructor: ->
    @screenLines = []

  insertAtBufferRow: (bufferRow, screenLines) ->
    screenLines = [screenLines] unless _.isArray(screenLines)
    delta = new Point
    insertIndex = 0

    for screenLine in @screenLines
      nextDelta = delta.add(screenLine.bufferDelta)
      break if nextDelta.row > bufferRow
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
    delta = new Point

    for screenLine, i in @screenLines
      startIndex = i if delta.row == startRow and not startIndex
      nextDelta = delta.add(screenLine[deltaType])
      break if nextDelta.row > stopRow
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
    delta = new Point

    for fragment in @screenLines
      break if delta.row > endRow
      if delta.row >= startRow
        if pendingFragment
          pendingFragment = pendingFragment.concat(fragment)
        else
          pendingFragment = fragment
        if pendingFragment.screenDelta.row > 0
          lines.push pendingFragment
          pendingFragment = null
      delta = delta.add(fragment.screenDelta)
    lines

  lineForBufferRow: (row) ->
    line = null
    delta = new Point
    for fragment in @screenLines
      break if delta.row > row
      if delta.row == row
        if line
          line = line.concat(fragment)
        else
          line = fragment
      delta = delta.add(fragment.bufferDelta)
    line

  bufferLineCount: ->
    delta = new Point
    for screenLine in @screenLines
      delta = delta.add(screenLine.bufferDelta)
    delta.row

  screenLineCount: ->
    delta = new Point
    for screenLine in @screenLines
      delta = delta.add(screenLine.screenDelta)
    delta.row

  screenPositionForBufferPosition: (bufferPosition, eagerWrap=true) ->
    bufferPosition = Point.fromObject(bufferPosition)
    bufferDelta = new Point
    screenDelta = new Point

    for screenLine in @screenLines
      nextDelta = bufferDelta.add(screenLine.bufferDelta)
      break if nextDelta.isGreaterThan(bufferPosition)
      break if nextDelta.isEqual(bufferPosition) and not eagerWrap
      bufferDelta = nextDelta
      screenDelta = screenDelta.add(screenLine.screenDelta)

    remainingBufferColumn = bufferPosition.column - bufferDelta.column
    additionalScreenColumn = Math.max(0, Math.min(remainingBufferColumn, screenLine.lengthForClipping()))

    new Point(screenDelta.row, screenDelta.column + additionalScreenColumn)

  bufferPositionForScreenPosition: (screenPosition) ->
    screenPosition = Point.fromObject(screenPosition)
    bufferDelta = new Point
    screenDelta = new Point

    for screenLine in @screenLines
      nextDelta = screenDelta.add(screenLine.screenDelta)
      break if nextDelta.isGreaterThan(screenPosition)
      screenDelta = nextDelta
      bufferDelta = bufferDelta.add(screenLine.bufferDelta)

    column = bufferDelta.column + (screenPosition.column - screenDelta.column)
    new Point(bufferDelta.row, column)

  screenRangeForBufferRange: (bufferRange) ->
    start = @screenPositionForBufferPosition(bufferRange.start)
    end = @screenPositionForBufferPosition(bufferRange.end)
    new Range(start, end)

  clipScreenPosition: (screenPosition) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = new Point(Math.max(0, screenPosition.row), Math.max(0, screenPosition.column))

    screenDelta = new Point
    for screenLine in @screenLines
      nextDelta = screenDelta.add(screenLine.screenDelta)
      break if nextDelta.isGreaterThan(screenPosition)
      screenDelta = nextDelta

    maxColumn = screenDelta.column + screenLine.lengthForClipping()
    screenDelta.column = Math.min(maxColumn, screenPosition.column)

    screenDelta

