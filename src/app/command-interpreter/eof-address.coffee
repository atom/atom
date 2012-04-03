Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class EofAddress extends Address
  getRange: (editor) ->
    lastRow = editor.getLastBufferRow()
    column = editor.lineLengthForBufferRow(lastRow)
    new Range([lastRow, column], [lastRow, column])

  isRelative: -> false
