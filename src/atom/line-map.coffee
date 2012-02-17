_ = require 'underscore'
Delta = require 'delta'

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
    stopRow = startRow + rowCount
    startIndex = undefined
    stopIndex = 0
    delta = new Delta

    for lineFragment, i in @lineFragments
      startIndex ?= i if delta.rows == startRow
      nextDelta = delta.add(lineFragment.bufferDelta)
      break if nextDelta.rows > stopRow
      delta = nextDelta
      stopIndex++

    @lineFragments[startIndex...stopIndex] = lineFragments

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

  bufferLineCount: ->
    delta = new Delta
    for lineFragment in @lineFragments
      delta = delta.add(lineFragment.bufferDelta)
    delta.rows
