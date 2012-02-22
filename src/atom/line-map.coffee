_ = require 'underscore'
Delta = require 'delta'
Point = require 'point'
Range = require 'range'

module.exports =
class LineMap
  constructor: ->
    @lineFragments = []

  insertAtBufferRow: (bufferRow, lineFragments) ->
    lineFragments = [lineFragments] unless _.isArray(lineFragments)
    delta = new Delta
    insertIndex = 0

    for lineFragment in @lineFragments
      nextDelta = delta.add(lineFragment.bufferDelta)
      break if nextDelta.rows > bufferRow
      delta = nextDelta
      insertIndex++

    @lineFragments[insertIndex...insertIndex] = lineFragments

  spliceAtBufferRow: (startRow, rowCount, lineFragments) ->
    @spliceByDelta('bufferDelta', startRow, rowCount, lineFragments)

  spliceAtScreenRow: (startRow, rowCount, lineFragments) ->
    @spliceByDelta('screenDelta', startRow, rowCount, lineFragments)

  spliceByDelta: (deltaType, startRow, rowCount, lineFragments) ->
    stopRow = startRow + rowCount
    startIndex = undefined
    stopIndex = 0
    delta = new Delta

    for lineFragment, i in @lineFragments
      startIndex = i if delta.rows == startRow and not startIndex
      nextDelta = delta.add(lineFragment[deltaType])
      break if nextDelta.rows > stopRow
      delta = nextDelta
      stopIndex++

    @lineFragments[startIndex...stopIndex] = lineFragments

  replaceBufferRows: (start, end, lineFragments) ->
    @spliceAtBufferRow(start, end - start + 1, lineFragments)

  replaceScreenRows: (start, end, lineFragments) ->
    @spliceAtScreenRow(start, end - start + 1, lineFragments)

  lineFragmentsForScreenRow: (screenRow) ->
    @lineFragmentsForScreenRows(screenRow, screenRow)

  lineFragmentsForScreenRows: (startRow, endRow) ->
    lineFragments = []
    delta = new Delta

    for lineFragment in @lineFragments
      break if delta.rows > endRow
      lineFragments.push(lineFragment) if delta.rows >= startRow
      delta = delta.add(lineFragment.screenDelta)

    lineFragments

  lineForScreenRow: (row) ->
    @linesForScreenRows(row, row)[0]

  linesForScreenRows: (startRow, endRow) ->
    lastLine = null
    lines = []
    delta = new Delta

    for fragment in @lineFragments
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
    for fragment in @lineFragments
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
    for lineFragment in @lineFragments
      delta = delta.add(lineFragment.bufferDelta)
    delta.rows

  screenLineCount: ->
    delta = new Delta
    for lineFragment in @lineFragments
      delta = delta.add(lineFragment.screenDelta)
    delta.rows

  screenPositionForBufferPosition: (bufferPosition, eagerWrap=true) ->
    bufferPosition = Point.fromObject(bufferPosition)
    bufferDelta = new Delta
    screenDelta = new Delta

    for lineFragment in @lineFragments
      nextDelta = bufferDelta.add(lineFragment.bufferDelta)
      break if nextDelta.toPoint().greaterThan(bufferPosition)
      break if nextDelta.toPoint().isEqual(bufferPosition) and not eagerWrap

      bufferDelta = nextDelta
      screenDelta = screenDelta.add(lineFragment.screenDelta)

    columns = screenDelta.columns + (bufferPosition.column - bufferDelta.columns)
    new Point(screenDelta.rows, columns)

  bufferPositionForScreenPosition: (screenPosition) ->
    screenPosition = Point.fromObject(screenPosition)
    bufferDelta = new Delta
    screenDelta = new Delta

    for lineFragment in @lineFragments
      nextDelta = screenDelta.add(lineFragment.screenDelta)
      break if nextDelta.toPoint().greaterThan(screenPosition)
      screenDelta = nextDelta
      bufferDelta = bufferDelta.add(lineFragment.bufferDelta)

    columns = bufferDelta.columns + (screenPosition.column - screenDelta.columns)
    new Point(bufferDelta.rows, columns)

  screenRangeForBufferRange: (bufferRange) ->
    start = @screenPositionForBufferPosition(bufferRange.start)
    end = @screenPositionForBufferPosition(bufferRange.end)
    new Range(start, end)

