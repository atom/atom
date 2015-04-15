{spliceWithArray} = require 'underscore-plus'

# Used by the display buffer to map screen rows to buffer rows and vice-versa.
# This mapping may not be 1:1 due to folds and soft-wraps. This object maintains
# an array of regions, which contain `bufferRows` and `screenRows` fields.
#
# Rectangular Regions:
# If a region has the same number of buffer rows and screen rows, it is referred
# to as "rectangular", and represents one or more non-soft-wrapped, non-folded
# lines.
#
# Trapezoidal Regions:
# If a region has one buffer row and more than one screen row, it represents a
# soft-wrapped line. If a region has one screen row and more than one buffer
# row, it represents folded lines
module.exports =
class RowMap
  constructor: ->
    @regions = []

  # Public: Returns a copy of all the regions in the map
  getRegions: ->
    @regions.slice()

  # Public: Returns an end-row-exclusive range of screen rows corresponding to
  # the given buffer row. If the buffer row is soft-wrapped, the range may span
  # multiple screen rows. Otherwise it will span a single screen row.
  screenRowRangeForBufferRow: (targetBufferRow) ->
    {region, bufferRows, screenRows} = @traverseToBufferRow(targetBufferRow)

    if region? and region.bufferRows isnt region.screenRows
      [screenRows, screenRows + region.screenRows]
    else
      screenRows += targetBufferRow - bufferRows
      [screenRows, screenRows + 1]

  # Public: Returns an end-row-exclusive range of buffer rows corresponding to
  # the given screen row. If the screen row is the first line of a folded range
  # of buffer rows, the range may span multiple buffer rows. Otherwise it will
  # span a single buffer row.
  bufferRowRangeForScreenRow: (targetScreenRow) ->
    {region, screenRows, bufferRows} = @traverseToScreenRow(targetScreenRow)
    if region? and region.bufferRows isnt region.screenRows
      [bufferRows, bufferRows + region.bufferRows]
    else
      bufferRows += targetScreenRow - screenRows
      [bufferRows, bufferRows + 1]

  # Public: If the given buffer row is part of a folded row range, returns that
  # row range. Otherwise returns a range spanning only the given buffer row.
  bufferRowRangeForBufferRow: (targetBufferRow) ->
    {region, bufferRows} = @traverseToBufferRow(targetBufferRow)
    if region? and region.bufferRows isnt region.screenRows
      [bufferRows, bufferRows + region.bufferRows]
    else
      [targetBufferRow, targetBufferRow + 1]

  # Public: Given a starting buffer row, the number of buffer rows to replace,
  # and an array of regions of shape {bufferRows: n, screenRows: m}, splices
  # the regions at the appropriate location in the map. This method is used by
  # display buffer to keep the map updated when the underlying buffer changes.
  spliceRegions: (startBufferRow, bufferRowCount, regions) ->
    endBufferRow = startBufferRow + bufferRowCount
    {index, bufferRows} = @traverseToBufferRow(startBufferRow)
    precedingRows = startBufferRow - bufferRows

    count = 0
    while region = @regions[index + count]
      count++
      bufferRows += region.bufferRows
      if bufferRows >= endBufferRow
        followingRows = bufferRows - endBufferRow
        break

    if precedingRows > 0
      regions.unshift({bufferRows: precedingRows, screenRows: precedingRows})

    if followingRows > 0
      regions.push({bufferRows: followingRows, screenRows: followingRows})

    spliceWithArray(@regions, index, count, regions)
    @mergeAdjacentRectangularRegions(index - 1, index + regions.length)

  traverseToBufferRow: (targetBufferRow) ->
    bufferRows = 0
    screenRows = 0
    for region, index in @regions
      if (bufferRows + region.bufferRows) > targetBufferRow
        return {region, index, screenRows, bufferRows}
      bufferRows += region.bufferRows
      screenRows += region.screenRows
    {index, screenRows, bufferRows}

  traverseToScreenRow: (targetScreenRow) ->
    bufferRows = 0
    screenRows = 0
    for region, index in @regions
      if (screenRows + region.screenRows) > targetScreenRow
        return {region, index, screenRows, bufferRows}
      bufferRows += region.bufferRows
      screenRows += region.screenRows
    {index, screenRows, bufferRows}

  mergeAdjacentRectangularRegions: (startIndex, endIndex) ->
    for index in [endIndex..startIndex]
      if 0 < index < @regions.length
        leftRegion = @regions[index - 1]
        rightRegion = @regions[index]
        leftIsRectangular = leftRegion.bufferRows is leftRegion.screenRows
        rightIsRectangular = rightRegion.bufferRows is rightRegion.screenRows
        if leftIsRectangular and rightIsRectangular
          @regions.splice index - 1, 2,
            bufferRows: leftRegion.bufferRows + rightRegion.bufferRows
            screenRows: leftRegion.screenRows + rightRegion.screenRows
    return

  # Public: Returns an array of strings describing the map's regions.
  inspect: ->
    for {bufferRows, screenRows} in @regions
      "#{bufferRows}:#{screenRows}"
