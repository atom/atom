_ = require 'underscore'
Point = require 'point'
Range = require 'range'

module.exports =
class LineMap
  constructor: ->
    @lineFragments = []

  insertAtBufferRow: (bufferRow, lineFragments) ->
    @spliceAtBufferRow(bufferRow, 0, lineFragments)

  spliceAtBufferRow: (startRow, rowCount, lineFragments) ->
    @spliceByDelta('bufferDelta', startRow, rowCount, lineFragments)

  spliceAtScreenRow: (startRow, rowCount, lineFragments) ->
    @spliceByDelta('screenDelta', startRow, rowCount, lineFragments)

  replaceBufferRows: (start, end, lineFragments) ->
    @spliceAtBufferRow(start, end - start + 1, lineFragments)

  replaceScreenRow: (row, lineFragments) ->
    @replaceScreenRows(row, row, lineFragments)

  replaceScreenRows: (start, end, lineFragments) ->
    @spliceAtScreenRow(start, end - start + 1, lineFragments)

  lineForScreenRow: (row) ->
    @linesForScreenRows(row, row)[0]

  linesForScreenRows: (startRow, endRow) ->
    @linesByDelta('screenDelta', startRow, endRow)

  lineForBufferRow: (row) ->
    @linesForBufferRows(row, row)[0]

  linesForBufferRows: (startRow, endRow) ->
    @linesByDelta('bufferDelta', startRow, endRow)

  bufferLineCount: ->
    @bufferPositionForScreenPosition([Infinity, 0]).row

  screenLineCount: ->
    @screenPositionForBufferPosition([Infinity, 0]).row

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

  logLines: (start=0, end=@screenLineCount() - 1)->
    for row in [start..end]
      line = @lineForScreenRow(row).text
      console.log row, line, line.length

  spliceByDelta: (deltaType, startRow, rowCount, lineFragments) ->
    stopRow = startRow + rowCount
    startIndex = undefined
    stopIndex = 0

    delta = new Point
    for lineFragment, i in @lineFragments
      startIndex ?= i if delta.row == startRow
      break if rowCount == 0 and delta.row == stopRow
      delta = delta.add(lineFragment[deltaType])
      break if delta.row > stopRow
      stopIndex++
    startIndex ?= i

    @lineFragments[startIndex...stopIndex] = lineFragments

  linesByDelta: (deltaType, startRow, endRow) ->
    lines = []
    delta = new Point

    for lineFragment in @lineFragments
      break if delta.row > endRow
      if delta.row >= startRow
        if pendingFragment
          pendingFragment = pendingFragment.concat(lineFragment)
        else
          pendingFragment = _.clone(lineFragment)
        if pendingFragment[deltaType].row > 0
          pendingFragment.bufferDelta = new Point(1, 0)
          lines.push pendingFragment
          pendingFragment = null
      delta = delta.add(lineFragment[deltaType])

    lines



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

