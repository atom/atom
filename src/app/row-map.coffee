module.exports =
class RowMap
  constructor: ->
    @mappings = []

  screenRowRangeForBufferRow: (targetBufferRow) ->
    { mapping, screenRow, bufferRow } = @traverseToBufferRow(targetBufferRow)
    if mapping and mapping.bufferRows != mapping.screenRows
      [screenRow, screenRow + mapping.screenRows]
    else
      screenRow += targetBufferRow - bufferRow
      [screenRow, screenRow + 1]

  bufferRowRangeForScreenRow: (screenRow) ->

  mapBufferRowRange: (startBufferRow, endBufferRow, screenRows) ->
    { mapping, index, bufferRow } = @traverseToBufferRow(startBufferRow)
    throw new Error("Invalid mapping insertion") if mapping and mapping.bufferRows != mapping.screenRows

    padBefore = startBufferRow - bufferRow
    padAfter = (bufferRow + mapping?.bufferRows) - endBufferRow

    newMappings = []
    newMappings.push(bufferRows: padBefore, screenRows: padBefore) if padBefore > 0
    newMappings.push(bufferRows: endBufferRow - startBufferRow, screenRows: screenRows)
    newMappings.push(bufferRows: padAfter, screenRows: padAfter) if padAfter > 0
    @mappings[index..index] = newMappings

  traverseToBufferRow: (targetBufferRow) ->
    bufferRow = 0
    screenRow = 0
    for mapping, index in @mappings
      if (bufferRow + mapping.bufferRows) > targetBufferRow
        return { mapping, index, screenRow, bufferRow }
      bufferRow += mapping.bufferRows
      screenRow += mapping.screenRows
    { index, screenRow, bufferRow }
      bufferRow += mapping.bufferRows
      screenRow += mapping.screenRows
    { mapping, index, screenRow, bufferRow }
