module.exports =
class RowMap
  constructor: ->
    @mappings = []

  screenRowRangeForBufferRow: (targetBufferRow) ->
    { mapping, screenRow, bufferRow } = @traverseToBufferRow(targetBufferRow)
    if mapping and mapping.bufferRows != mapping.screenRows # 1:n mapping
      [screenRow, screenRow + mapping.screenRows]
    else                                                    # 1:1 mapping
      screenRow += targetBufferRow - bufferRow
      [screenRow, screenRow + 1]

  bufferRowRangeForBufferRow: (targetBufferRow) ->
    { mapping, screenRow, bufferRow } = @traverseToBufferRow(targetBufferRow)
    if mapping and mapping.bufferRows != mapping.screenRows # 1:n mapping
      [bufferRow, bufferRow + mapping.bufferRows]
    else                                                    # 1:1 mapping
      [targetBufferRow, targetBufferRow + 1]

  bufferRowRangeForScreenRow: (targetScreenRow) ->
    { mapping, screenRow, bufferRow } = @traverseToScreenRow(targetScreenRow)
    if mapping and mapping.bufferRows != mapping.screenRows # 1:n mapping
      [bufferRow, bufferRow + mapping.bufferRows]
    else                                                    # 1:1 mapping
      bufferRow += targetScreenRow - screenRow
      [bufferRow, bufferRow + 1]

  mapBufferRowRange: (startBufferRow, endBufferRow, screenRows) ->
    { mapping, index, bufferRow, screenRow } = @traverseToBufferRow(startBufferRow)

    newMappings = []

    preRows = startBufferRow - bufferRow
    if preRows > 0
      newMappings.push(bufferRows: preRows, screenRows: preRows)

    bufferRows = endBufferRow - startBufferRow
    newMappings.push({bufferRows, screenRows})

    if mapping
      postBufferRows = mapping.bufferRows - preRows - bufferRows
      postScreenRows = mapping.screenRows - preRows - screenRows
      if postBufferRows > 0 or postScreenRows > 0
        newMappings.push(bufferRows: postBufferRows, screenRows: postScreenRows)

    @mappings[index..index] = newMappings

  applyBufferDelta: (startBufferRow, delta) ->
    { mapping } = @traverseToBufferRow(startBufferRow)
    mapping?.bufferRows += delta

  applyScreenDelta: (startBufferRow, delta) ->
    { mapping } = @traverseToScreenRow(startBufferRow)
    mapping?.screenRows += delta

  traverseToBufferRow: (targetBufferRow) ->
    bufferRow = 0
    screenRow = 0
    for mapping, index in @mappings
      if (bufferRow + mapping.bufferRows) > targetBufferRow
        return { mapping, index, screenRow, bufferRow }
      bufferRow += mapping.bufferRows
      screenRow += mapping.screenRows
    { index, screenRow, bufferRow }

  traverseToScreenRow: (targetScreenRow) ->
    bufferRow = 0
    screenRow = 0
    for mapping, index in @mappings
      if (screenRow + mapping.screenRows) > targetScreenRow
        return { mapping, index, screenRow, bufferRow }
      bufferRow += mapping.bufferRows
      screenRow += mapping.screenRows
    { index, screenRow, bufferRow }
