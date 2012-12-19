Address = require 'command-panel/src/commands/address'
Range = require 'range'

module.exports =
class CurrentSelectionAddress extends Address
  getRange: (buffer, range) ->
    range

  isRelative: -> true
