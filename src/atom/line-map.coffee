_ = require 'underscore'
Point = require 'point'
Range = require 'range'

module.exports =
class LineMap
  constructor: ->
    @lineFragments = []

  insertAtBufferRow: (bufferRow, lineFragments) ->
    delta = new Point
    insertIndex = 0

    for lineFragment in @lineFragments
      nextDelta = delta.add(lineFragment.bufferDelta)
      break if nextDelta.row > bufferRow
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
    delta = new Point

    for lineFragment, i in @lineFragments
      startIndex ?= i if delta.row == startRow
      nextDelta = delta.add(lineFragment[deltaType])
      break if nextDelta.row > stopRow
      delta = nextDelta
      stopIndex++

    @lineFragments[startIndex...stopIndex] = lineFragments

  replaceBufferRows: (start, end, lineFragments) ->
    @spliceAtBufferRow(start, end - start + 1, lineFragments)

  replaceScreenRow: (row, lineFragments) ->
    @replaceScreenRows(row, row, lineFragments)

  replaceScreenRows: (start, end, lineFragments) ->
    @spliceAtScreenRow(start, end - start + 1, lineFragments)

  lineForScreenRow: (row) ->
    @linesForScreenRows(row, row)[0]

  linesForScreenRows: (startRow, endRow) ->
    lines = []
    delta = new Point

    for lineFragment in @lineFragments
      break if delta.row > endRow
      if delta.row >= startRow
        if pendingFragment
          pendingFragment = pendingFragment.concat(lineFragment)
        else
          pendingFragment = _.clone(lineFragment)
        if pendingFragment.screenDelta.row > 0
          pendingFragment.bufferDelta = new Point(1, 0)
          lines.push pendingFragment
          pendingFragment = null
      delta = delta.add(lineFragment.screenDelta)

    lines

  lineForBufferRow: (row) ->
    line = null
    delta = new Point
    for lineFragment in @lineFragments
      break if delta.row > row
      if delta.row == row
        if line
          line = line.concat(lineFragment)
        else
          line = lineFragment
      delta = delta.add(lineFragment.bufferDelta)
    line

  bufferLineCount: ->
    delta = new Point
    for lineFragment in @lineFragments
      delta = delta.add(lineFragment.bufferDelta)
    delta.row

  screenLineCount: ->
    delta = new Point
    for lineFragment in @lineFragments
      delta = delta.add(lineFragment.screenDelta)
    delta.row

  lastScreenRow: ->
    @screenLineCount() - 1

  screenPositionForBufferPosition: (bufferPosition) ->
    @translatePosition('bufferDelta', 'screenDelta', bufferPosition)

  bufferPositionForScreenPosition: (screenPosition) ->
    @translatePosition('screenDelta', 'bufferDelta', screenPosition)

  screenRangeForBufferRange: (bufferRange) ->
    start = @screenPositionForBufferPosition(bufferRange.start)
    end = @screenPositionForBufferPosition(bufferRange.end)
    new Range(start, end)

  bufferRangeForScreenRange: (screenRange) ->
    start = @bufferPositionForScreenPosition(screenRange.start)
    end = @bufferPositionForScreenPosition(screenRange.end)
    new Range(start, end)

  translatePosition: (sourceDeltaType, targetDeltaType, sourcePosition) ->
    sourcePosition = Point.fromObject(sourcePosition)
    sourceDelta = new Point
    targetDelta = new Point

    for lineFragment in @lineFragments
      nextSourceDelta = sourceDelta.add(lineFragment[sourceDeltaType])
      break if nextSourceDelta.isGreaterThan(sourcePosition)
      sourceDelta = nextSourceDelta
      targetDelta = targetDelta.add(lineFragment[targetDeltaType])

    unless lineFragment.isAtomic
      targetDelta.column += Math.max(0, sourcePosition.column - sourceDelta.column)

    targetDelta


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
    for lineFragment in @lineFragments
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
