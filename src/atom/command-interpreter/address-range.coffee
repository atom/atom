Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class AddressRange extends Address
  constructor: (@startAddress, @endAddress) ->

  getRange: (editor) ->
    new Range(@startAddress.getRange(editor).start, @endAddress.getRange(editor).end)
