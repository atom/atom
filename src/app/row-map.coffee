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

    newRegions = []

    preRows = startBufferRow - bufferRow
    if preRows > 0
      newRegions.push(bufferRows: preRows, screenRows: preRows)

    bufferRows = endBufferRow - startBufferRow
    newRegions.push({bufferRows, screenRows})

    startIndex = index
    endIndex = index
    while bufferRows > 0 and endIndex < @regions.length
      region = @regions[endIndex]
      if region.bufferRows < bufferRows
        bufferRows -= region.bufferRows
        endIndex++
      else
        postBufferRows = region.bufferRows - preRows - bufferRows
        postScreenRows = region.screenRows - preRows - screenRows
        if postBufferRows > 0 or postScreenRows > 0
          newRegions.push(bufferRows: postBufferRows, screenRows: postScreenRows)
        bufferRows = 0

    @regions[startIndex..endIndex] = newRegions

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
