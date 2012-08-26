Address = require 'command-panel/commands/address'
Range = require 'range'

module.exports =
class CurrentSelectionAddress extends Address
  getRange: (buffer, range) ->
    range

  isRelative: -> true
