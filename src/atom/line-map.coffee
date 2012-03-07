_ = require 'underscore'
Point = require 'point'
Range = require 'range'

module.exports =
class LineMap
  constructor: ->
    @lineFragments = []

  insertAtInputRow: (inputRow, lineFragments) ->
    @spliceAtInputRow(inputRow, 0, lineFragments)

  spliceAtInputRow: (startRow, rowCount, lineFragments) ->
    @spliceByDelta('inputDelta', startRow, rowCount, lineFragments)

  spliceAtOutputRow: (startRow, rowCount, lineFragments) ->
    @spliceByDelta('outputDelta', startRow, rowCount, lineFragments)

  replaceInputRows: (start, end, lineFragments) ->
    @spliceAtInputRow(start, end - start + 1, lineFragments)

  replaceOutputRow: (row, lineFragments) ->
    @replaceOutputRows(row, row, lineFragments)

  replaceOutputRows: (start, end, lineFragments) ->
    @spliceAtOutputRow(start, end - start + 1, lineFragments)

  lineForOutputRow: (row) ->
    @linesForOutputRows(row, row)[0]

  linesForOutputRows: (startRow, endRow) ->
    @linesByDelta('outputDelta', startRow, endRow)

  lineForInputRow: (row) ->
    @linesForInputRows(row, row)[0]

  linesForInputRows: (startRow, endRow) ->
    @linesByDelta('inputDelta', startRow, endRow)

  inputLineCount: ->
    @lineCountByDelta('inputDelta')

  outputLineCount: ->
    @lineCountByDelta('outputDelta')

  lineCountByDelta: (deltaType) ->
    @traverseByDelta(deltaType, new Point(Infinity, 0))[deltaType].row

  lastOutputRow: ->
    @outputLineCount() - 1

  outputPositionForInputPosition: (inputPosition) ->
    @translatePosition('inputDelta', 'outputDelta', inputPosition)

  inputPositionForOutputPosition: (outputPosition) ->
    @translatePosition('outputDelta', 'inputDelta', outputPosition)

  outputRangeForInputRange: (inputRange) ->
    start = @outputPositionForInputPosition(inputRange.start)
    end = @outputPositionForInputPosition(inputRange.end)
    new Range(start, end)

  inputRangeForOutputRange: (outputRange) ->
    start = @inputPositionForOutputPosition(outputRange.start)
    end = @inputPositionForOutputPosition(outputRange.end)
    new Range(start, end)

  clipOutputPosition: (outputPosition, options) ->
    @clipPosition('outputDelta', outputPosition, options)

  clipPosition: (deltaType, position, options) ->
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
    @traverseByDelta deltaType, new Point(startRow, 0), new Point(endRow, Infinity), (lineFragment) ->
      if pendingFragment
        pendingFragment = pendingFragment.concat(lineFragment)
      else
        pendingFragment = _.clone(lineFragment)
      if pendingFragment[deltaType].row > 0
        pendingFragment.inputDelta = new Point(1, 0)
        lines.push pendingFragment
        pendingFragment = null
    lines

  translatePosition: (sourceDeltaType, targetDeltaType, sourcePosition, options={}) ->
    sourcePosition = Point.fromObject(sourcePosition)
    wrapBeyondNewlines = options.wrapBeyondNewlines ? false
    wrapAtSoftNewlines = options.wrapAtSoftNewlines ? false
    skipAtomicTokens = options.skipAtomicTokens ? false

    @clipToBounds(sourceDeltaType, sourcePosition)
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
    else if lastLineFragment.isAtomic
      if skipAtomicTokens and sourcePosition.column > sourceDelta.column
        targetDelta.column += lastLineFragment.text.length
    else
      additionalColumns = sourcePosition.column - sourceDelta.column
      targetDelta.column = Math.min(maxTargetColumn, targetDelta.column + additionalColumns)

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
    outputDelta = new Point
    inputDelta = new Point

    for lineFragment in @lineFragments
      iterator(lineFragment) if traversalDelta.isGreaterThanOrEqual(startPosition) and iterator?
      traversalDelta = traversalDelta.add(lineFragment[deltaType])
      break if traversalDelta.isGreaterThan(endPosition)
      outputDelta = outputDelta.add(lineFragment.outputDelta)
      inputDelta = inputDelta.add(lineFragment.inputDelta)

    { outputDelta, inputDelta, lastLineFragment: lineFragment }

  logLines: (start=0, end=@outputLineCount() - 1)->
    for row in [start..end]
      line = @lineForOutputRow(row).text
      console.log row, line, line.length

