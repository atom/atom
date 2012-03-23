Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class EofAddress extends Address
  getRange: (editor) ->
    lastRow = editor.getLastBufferRow()
    column = editor.getBufferLineLength(lastRow)
    new Range([lastRow, column], [lastRow, column])

  isRelative: -> false
