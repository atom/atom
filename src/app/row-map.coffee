module.exports =
class RowMap
  constructor: ->
    @mappings = []

  screenRowRangeForBufferRow: (targetBufferRow) ->
    bufferRow = 0
    screenRow = 0

    for mapping in @mappings
      if bufferRow <= targetBufferRow < bufferRow + mapping.bufferRows
        if mapping.bufferRows == mapping.screenRows # 1:1 mapping region
          break
        else # fold or wrapped line mapping
          return [screenRow, screenRow + mapping.screenRows]
      bufferRow += mapping.bufferRows
      screenRow += mapping.screenRows

    screenRow += targetBufferRow - bufferRow
    return [screenRow, screenRow + 1]

  bufferRowRangeForScreenRow: (screenRow) ->

  mapBufferRowRange: (startBufferRow, endBufferRow, screenRows) ->
    bufferRow = 0

    for mapping, index in @mappings
      if (bufferRow + mapping.bufferRows) > startBufferRow
        throw new Error("Invalid mapping insertion") unless mapping.bufferRows == mapping.screenRows
        dividedMapping = mapping
        break
      bufferRow += mapping.bufferRows

    padBefore = startBufferRow - bufferRow
    padAfter = (bufferRow + dividedMapping?.bufferRows) - endBufferRow

    newMappings = []
    newMappings.push(bufferRows: padBefore, screenRows: padBefore) if padBefore > 0
    newMappings.push(bufferRows: endBufferRow - startBufferRow, screenRows: screenRows)
    newMappings.push(bufferRows: padAfter, screenRows: padAfter) if padAfter > 0
    @mappings[index..index] = newMappings
