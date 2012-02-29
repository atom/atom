_ = require 'underscore'
Point = require 'point'
Range = require 'range'

module.exports =
class LineMap
  constructor: ->
    @screenLines = []

  insertAtBufferRow: (bufferRow, screenLines) ->
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
      startIndex ?= i if delta.row == startRow
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

  lineForScreenRow: (row) ->
    @linesForScreenRows(row, row)[0]

  linesForScreenRows: (startRow, endRow) ->
    lines = []
    delta = new Point

    for fragment in @screenLines
      break if delta.row > endRow
      if delta.row >= startRow
        if pendingFragment
          pendingFragment = pendingFragment.concat(fragment)
        else
          pendingFragment = _.clone(fragment)
        if pendingFragment.screenDelta.row > 0
          pendingFragment.bufferDelta = new Point(1, 0)
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

  lastScreenRow: ->
    @screenLineCount() - 1

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

  bufferRangeForScreenRange: (screenRange) ->
    start = @bufferPositionForScreenPosition(screenRange.start)
    end = @bufferPositionForScreenPosition(screenRange.end)
    new Range(start, end)

  clipScreenPosition: (screenPosition, options) ->
    wrapBeyondNewlines = options.wrapBeyondNewlines ? false
    wrapAtSoftNewlines = options.wrapAtSoftNewlines ? false
    skipAtomicTokens = options.skipAtomicTokens ? false
    screenPosition = Point.fromObject(screenPosition)

    screenPosition.column = Math.max(0, screenPosition.column)

    if screenPosition.row < 0
      screenPosition.row = 0
      screenPosition.column = 0

    if screenPosition.row > @lastScreenRow()
      screenPosition.row = @lastScreenRow()
      screenPosition.column = Infinity

    screenDelta = new Point
    for lineFragment in @screenLines
      nextDelta = screenDelta.add(lineFragment.screenDelta)
      break if nextDelta.isGreaterThan(screenPosition)
      screenDelta = nextDelta

    if lineFragment.isAtomic
      if skipAtomicTokens and screenPosition.column > screenDelta.column
        return new Point(screenDelta.row, screenDelta.column + lineFragment.text.length)
      else
        return screenDelta

    maxColumn = screenDelta.column + lineFragment.text.length
    if lineFragment.isSoftWrapped() and screenPosition.column >= maxColumn
      if wrapAtSoftNewlines
        return new Point(screenDelta.row + 1, 0)
      else
        return new Point(screenDelta.row, maxColumn - 1)

    if screenPosition.column > maxColumn and wrapBeyondNewlines
      return new Point(screenDelta.row + 1, 0)

    new Point(screenDelta.row, Math.min(maxColumn, screenPosition.column))

  logLines: (start=0, end=@screenLineCount() - 1)->
    for row in [start..end]
      line = @lineForScreenRow(row).text
      console.log row, line, line.length
