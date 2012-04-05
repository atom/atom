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

  bufferRowsForScreenRows: (startRow, endRow=@lastScreenRow())->
    bufferRows = []
    currentScreenRow = -1
    @traverseByDelta 'screenDelta', [startRow, 0], [endRow, 0], ({ screenDelta, bufferDelta }) ->
      bufferRows.push(bufferDelta.row) if screenDelta.row > currentScreenRow
      currentScreenRow = screenDelta.row
    bufferRows

  bufferLineCount: ->
    @lineCountByDelta('bufferDelta')

  screenLineCount: ->
    @lineCountByDelta('screenDelta')

  lineCountByDelta: (deltaType) ->
    @traverseByDelta(deltaType, new Point(Infinity, 0))[deltaType].row

  lastScreenRow: ->
    @screenLineCount() - 1

  screenPositionForBufferPosition: (bufferPosition) ->
    @translatePosition('bufferDelta', 'screenDelta', bufferPosition)

  bufferPositionForScreenPosition: (screenPosition) ->
    @translatePosition('screenDelta', 'bufferDelta', screenPosition)

  screenRangeForBufferRange: (bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    start = @screenPositionForBufferPosition(bufferRange.start)
    end = @screenPositionForBufferPosition(bufferRange.end)
    new Range(start, end)

  bufferRangeForScreenRange: (screenRange) ->
    start = @bufferPositionForScreenPosition(screenRange.start)
    end = @bufferPositionForScreenPosition(screenRange.end)
    new Range(start, end)

  clipScreenPosition: (screenPosition, options) ->
    @clipPosition('screenDelta', screenPosition, options)

  clipPosition: (deltaType, position, options={}) ->
    options.clipToBounds = true
    @translatePosition(deltaType, deltaType, position, options)

  spliceByDelta: (deltaType, startRow, rowCount, lineFragments) ->
    stopRow = startRow + rowCount
    startIndex = undefined
    stopIndex = 0

    delta = new Point
    for lineFragment, i in @lineFragments
      startIndex ?= i if delta.row == startRow
      break if delta.row == stopRow
      delta = delta.add(lineFragment[deltaType])
      stopIndex++
    startIndex ?= i

    @lineFragments[startIndex...stopIndex] = lineFragments

  linesByDelta: (deltaType, startRow, endRow) ->
    lines = []
    pendingFragment = null
    @traverseByDelta deltaType, new Point(startRow, 0), new Point(endRow, Infinity), ({lineFragment}) ->
      if pendingFragment
        pendingFragment = pendingFragment.concat(lineFragment)
      else
        pendingFragment = lineFragment
      if pendingFragment[deltaType].row > 0
        lines.push pendingFragment
        pendingFragment = null
    lines

  translatePosition: (sourceDeltaType, targetDeltaType, sourcePosition, options={}) ->
    sourcePosition = Point.fromObject(sourcePosition)
    wrapBeyondNewlines = options.wrapBeyondNewlines ? false
    wrapAtSoftNewlines = options.wrapAtSoftNewlines ? false
    skipAtomicTokens = options.skipAtomicTokens ? false
    clipToBounds = options.clipToBounds ? false

    @clipToBounds(sourceDeltaType, sourcePosition) if clipToBounds
    traversalResult = @traverseByDelta(sourceDeltaType, sourcePosition)
    lastLineFragment = traversalResult.lastLineFragment
    sourceDelta = traversalResult[sourceDeltaType]
    targetDelta = traversalResult[targetDeltaType]

    return targetDelta unless lastLineFragment
    maxSourceColumn = sourceDelta.column + lastLineFragment.text.length
    maxTargetColumn = targetDelta.column + lastLineFragment.text.length

    if lastLineFragment.isSoftWrapped() and sourcePosition.column >= maxSourceColumn
      if wrapAtSoftNewlines
        targetDelta.row++
        targetDelta.column = 0
      else
        targetDelta.column = maxTargetColumn - 1
        return @clipPosition(targetDeltaType, targetDelta)
    else if sourcePosition.column > maxSourceColumn and wrapBeyondNewlines
      targetDelta.row++
      targetDelta.column = 0
    else
      additionalColumns = sourcePosition.column - sourceDelta.column
      targetDelta.column += lastLineFragment.clipColumn(additionalColumns, { skipAtomicTokens })

    targetDelta

  clipToBounds: (deltaType, position) ->
    if position.column < 0
      position.column = 0

    if position.row < 0
      position.row = 0
      position.column = 0

    maxSourceRow = @lineCountByDelta(deltaType) - 1
    if position.row > maxSourceRow
      position.row = maxSourceRow
      position.column = Infinity

  traverseByDelta: (deltaType, startPosition, endPosition=startPosition, iterator=null) ->
    traversalDelta = new Point
    screenDelta = new Point
    bufferDelta = new Point

    for lineFragment in @lineFragments
      iterator({ lineFragment, screenDelta, bufferDelta }) if traversalDelta.isGreaterThanOrEqual(startPosition) and iterator?
      traversalDelta = traversalDelta.add(lineFragment[deltaType])
      break if traversalDelta.isGreaterThan(endPosition)
      screenDelta = screenDelta.add(lineFragment.screenDelta)
      bufferDelta = bufferDelta.add(lineFragment.bufferDelta)

    { screenDelta, bufferDelta, lastLineFragment: lineFragment }

  logLines: (start=0, end=@screenLineCount() - 1)->
    for row in [start..end]
      line = @lineForScreenRow(row).text
      console.log row, line, line.length

