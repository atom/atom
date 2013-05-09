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
