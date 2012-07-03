Address = require 'command-panel/commands/address'
Range = require 'range'

module.exports =
class CurrentSelectionAddress extends Address
  getRange: (editor, currentRange) ->
    currentRange

  isRelative: -> true
