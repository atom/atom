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
    if mapping
      if mapping.bufferRows != mapping.screenRows and index < @mappings.length - 1
        throw new Error("Invalid mapping insertion")
    else
      index = 0

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
      break if (bufferRow + mapping.bufferRows) > targetBufferRow
      bufferRow += mapping.bufferRows
      screenRow += mapping.screenRows
    { mapping, index, screenRow, bufferRow }
