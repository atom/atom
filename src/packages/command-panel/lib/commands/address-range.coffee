Address = require 'command-panel/lib/commands/address'
{Range} = require 'telepath'

module.exports =
class AddressRange extends Address
  constructor: (@startAddress, @endAddress) ->

  getRange: (buffer, range) ->
    new Range(@startAddress.getRange(buffer, range).start, @endAddress.getRange(buffer, range).end)

  isRelative: ->
    @startAddress.isRelative() and @endAddress.isRelative()
