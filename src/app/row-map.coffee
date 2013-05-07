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
    [screenRow, screenRow]

  mapBufferRowRange: (startBufferRow, endBufferRow, screenRows) ->
    @mappings.push(bufferRows: startBufferRow, screenRows: startBufferRow)
    @mappings.push(bufferRows: endBufferRow - startBufferRow, screenRows: screenRows)
