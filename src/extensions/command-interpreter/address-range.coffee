Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class AddressRange extends Address
  constructor: (@startAddress, @endAddress) ->

  getRange: (editor, currentRange) ->
    new Range(@startAddress.getRange(editor, currentRange).start, @endAddress.getRange(editor, currentRange).end)

  isRelative: ->
    @startAddress.isRelative() and @endAddress.isRelative()
