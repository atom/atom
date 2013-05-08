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

  mapBufferRowRange: (startBufferRow, endBufferRow, screenRows) ->
    { index, bufferRow, screenRow } = @traverseToBufferRow(startBufferRow)

    overlapStartIndex = index
    overlapStartBufferRow = bufferRow
    overlapEndIndex = index
    overlapEndBufferRow = bufferRow
    overlapEndScreenRow = screenRow

    # determine regions that the new region overlaps. they will need replacement.
    while overlapEndIndex < @regions.length
      region = @regions[overlapEndIndex]
      overlapEndBufferRow += region.bufferRows
      overlapEndScreenRow += region.screenRows
      break if overlapEndBufferRow >= endBufferRow
      overlapEndIndex++

    # we will replace overlapStartIndex..overlapEndIndex with these regions
    newRegions = []

    # if we straddle the first overlapping region, push a smaller region representing
    # the portion before the new region
    preRows = startBufferRow - overlapStartBufferRow
    if preRows > 0
      newRegions.push(bufferRows: preRows, screenRows: preRows)

    # push the new region
    newRegions.push(bufferRows: endBufferRow - startBufferRow, screenRows: screenRows)

    # if we straddle the last overlapping region, push a smaller region representing
    # the portion after the new region
    if overlapEndBufferRow > endBufferRow
      endScreenRow = screenRow + preRows + screenRows
      newRegions.push(bufferRows: overlapEndBufferRow - endBufferRow, screenRows: overlapEndScreenRow - endScreenRow)

    @regions[overlapStartIndex..overlapEndIndex] = newRegions

  applyBufferDelta: (startBufferRow, delta) ->
    { region } = @traverseToBufferRow(startBufferRow)
    region?.bufferRows += delta

  applyScreenDelta: (startScreenRow, delta) ->
    { index } = @traverseToScreenRow(startScreenRow)
    while delta != 0 and index < @regions.length
      { bufferRows, screenRows } = @regions[index]
      screenRows += delta
      if screenRows < 0
        delta = screenRows
        screenRows = 0
      else
        delta = 0
      @regions[index] = { bufferRows, screenRows }
      index++

  traverseToBufferRow: (targetBufferRow) ->
    bufferRow = 0
    screenRow = 0
    for region, index in @regions
      if (bufferRow + region.bufferRows) > targetBufferRow
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
