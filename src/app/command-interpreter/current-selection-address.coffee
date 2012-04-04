Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class CurrentSelectionAddress extends Address
  getRange: (editor, currentRange) ->
    currentRange

  isRelative: -> true
