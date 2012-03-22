Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class AddressRange extends Address
  constructor: (@startAddress, @endAddress) ->

  getRange: ->
    new Range(@startAddress.getRange().start, @endAddress.getRange().end)
