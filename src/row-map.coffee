# Private: Maintains the canonical map between screen and buffer positions.
#
# Facilitates the mapping of screen rows to buffer rows and vice versa. All row
# ranges dealt with by this class are end-row exclusive. For example, a fold of
# rows 4 through 8 would be expressed as `mapBufferRowRange(4, 9, 1)`, which maps
# the region from 4 to 9 in the buffer to a single screen row. Conversely, a
# soft-wrapped screen line means there are multiple screen rows corresponding to
# a single buffer row, as follows: `mapBufferRowRange(4, 5, 3)`. That says that
# buffer row 4 maps to 3 rows on screen.
#
# The RowMap revolves around the `@regions` array. Each region describes a number
# of rows in both the screen and buffer coordinate spaces. So if you inserted a
# single fold from 5-10, the regions array would look like this:
#
# ```
# [{bufferRows: 5, screenRows: 5}, {bufferRows: 5, screenRows: 1}]
# ```
#
# The first region expresses an iso-mapping, a region in which one buffer row
# is equivalent to one screen row. The second region expresses the fold, with
# 5 buffer rows mapping to a single screen row. Position translation functions
# by traversing through these regions and summing the number of rows traversed
# in both the screen and the buffer.
module.exports =
class RowMap
  constructor: ->
    @regions = []

  screenRowRangeForBufferRow: (targetBufferRow) ->
    { region, screenRow, bufferRow } = @traverseToBufferRow(targetBufferRow)
    if region and region.bufferRows != region.screenRows # 1:n region
      [screenRow, screenRow + region.screenRows]
    else                                                    # 1:1 region
      screenRow += targetBufferRow - bufferRow
      [screenRow, screenRow + 1]

  # This will return just the given buffer row if it is part of an iso region,
  # but if it is part of a fold it will return the range of the entire fold. This
  # helps the DisplayBuffer always start processing at the beginning of a fold
  # for changes that occur inside the fold.
  bufferRowRangeForBufferRow: (targetBufferRow) ->
    { region, screenRow, bufferRow } = @traverseToBufferRow(targetBufferRow)
    if region and region.bufferRows != region.screenRows # 1:n region
      [bufferRow, bufferRow + region.bufferRows]
    else                                                    # 1:1 region
      [targetBufferRow, targetBufferRow + 1]

  bufferRowRangeForScreenRow: (targetScreenRow) ->
    { region, screenRow, bufferRow } = @traverseToScreenRow(targetScreenRow)
    if region and region.bufferRows != region.screenRows # 1:n region
      [bufferRow, bufferRow + region.bufferRows]
    else                                                    # 1:1 region
      bufferRow += targetScreenRow - screenRow
      [bufferRow, bufferRow + 1]

  # This method is used to create new regions, storing a mapping between a range
  # of buffer rows to a certain number of screen rows. It will never add or remove
  # rows in either coordinate space, meaning that it never changes the position
  # of subsequent regions. It will overwrite or split existing regions that overlap
  # with the region being stored however.
  mapBufferRowRange: (startBufferRow, endBufferRow, screenRows) ->
    { index, bufferRow, screenRow } = @traverseToBufferRow(startBufferRow)

    overlapStartIndex = index
    overlapStartBufferRow = bufferRow
    preRows = startBufferRow - overlapStartBufferRow
    endScreenRow = screenRow + preRows + screenRows
    overlapEndIndex = index
    overlapEndBufferRow = bufferRow
    overlapEndScreenRow = screenRow

    # determine regions that the new region overlaps. they will need replacement.
    while overlapEndIndex < @regions.length
      region = @regions[overlapEndIndex]
      overlapEndBufferRow += region.bufferRows
      overlapEndScreenRow += region.screenRows
      break if overlapEndBufferRow >= endBufferRow and overlapEndScreenRow >= endScreenRow
      overlapEndIndex++

    # we will replace overlapStartIndex..overlapEndIndex with these regions
    newRegions = []

    # if we straddle the first overlapping region, push a smaller region representing
    # the portion before the new region
    if preRows > 0
      newRegions.push(bufferRows: preRows, screenRows: preRows)

    # push the new region
    newRegions.push(bufferRows: endBufferRow - startBufferRow, screenRows: screenRows)

    # if we straddle the last overlapping region, push a smaller region representing
    # the portion after the new region
    if overlapEndBufferRow > endBufferRow
      newRegions.push(bufferRows: overlapEndBufferRow - endBufferRow, screenRows: overlapEndScreenRow - endScreenRow)

    @regions[overlapStartIndex..overlapEndIndex] = newRegions
    @mergeIsomorphicRegions(Math.max(0, overlapStartIndex - 1), Math.min(@regions.length - 1, overlapEndIndex + 1))

  mergeIsomorphicRegions: (startIndex, endIndex) ->
    return if startIndex == endIndex

    region = @regions[startIndex]
    nextRegion = @regions[startIndex + 1]
    if region.bufferRows == region.screenRows and nextRegion.bufferRows == nextRegion.screenRows
      @regions[startIndex..startIndex + 1] =
        bufferRows: region.bufferRows + nextRegion.bufferRows
        screenRows: region.screenRows + nextRegion.screenRows
      @mergeIsomorphicRegions(startIndex, endIndex - 1)
    else
      @mergeIsomorphicRegions(startIndex + 1, endIndex)

  # This method records insertion or removal of rows in the buffer, adjusting the
  # buffer dimension of regions following the start row accordingly.
  applyBufferDelta: (startBufferRow, delta) ->
    return if delta is 0
    { index, bufferRow } = @traverseToBufferRow(startBufferRow)
    if delta > 0 and index < @regions.length
      { bufferRows, screenRows } = @regions[index]
      bufferRows += delta
      @regions[index] = { bufferRows, screenRows }
    else
      delta = -delta
      while delta > 0 and index < @regions.length
        { bufferRows, screenRows } = @regions[index]
        regionStartBufferRow = bufferRow
        regionEndBufferRow = bufferRow + bufferRows
        maxDelta = regionEndBufferRow - Math.max(regionStartBufferRow, startBufferRow)
        regionDelta = Math.min(delta, maxDelta)
        bufferRows -= regionDelta
        @regions[index] = { bufferRows, screenRows }
        delta -= regionDelta
        bufferRow += bufferRows
        index++

  # This method records insertion or removal of rows on the screen, adjusting the
  # screen dimension of regions following the start row accordingly.
  applyScreenDelta: (startScreenRow, delta) ->
    return if delta is 0
    { index, screenRow } = @traverseToScreenRow(startScreenRow)
    if delta > 0 and index < @regions.length
      { bufferRows, screenRows } = @regions[index]
      screenRows += delta
      @regions[index] = { bufferRows, screenRows }
    else
      delta = -delta
      while delta > 0 and index < @regions.length
        { bufferRows, screenRows } = @regions[index]
        regionStartScreenRow = screenRow
        regionEndScreenRow = screenRow + screenRows
        maxDelta = regionEndScreenRow - Math.max(regionStartScreenRow, startScreenRow)
        regionDelta = Math.min(delta, maxDelta)
        screenRows -= regionDelta
        @regions[index] = { bufferRows, screenRows }
        delta -= regionDelta
        screenRow += screenRows
        index++

  traverseToBufferRow: (targetBufferRow) ->
    bufferRow = 0
    screenRow = 0
    for region, index in @regions
      if (bufferRow + region.bufferRows) > targetBufferRow or region.bufferRows == 0 and bufferRow == targetBufferRow
        return { region, index, screenRow, bufferRow }
      bufferRow += region.bufferRows
      screenRow += region.screenRows
    { index, screenRow, bufferRow }

  traverseToScreenRow: (targetScreenRow) ->
    bufferRow = 0
    screenRow = 0
    for region, index in @regions
      if (screenRow + region.screenRows) > targetScreenRow
        return { region, index, screenRow, bufferRow }
      bufferRow += region.bufferRows
      screenRow += region.screenRows
    { index, screenRow, bufferRow }

  inspect: ->
    @regions.map(({screenRows, bufferRows}) -> "#{screenRows}:#{bufferRows}").join(', ')
