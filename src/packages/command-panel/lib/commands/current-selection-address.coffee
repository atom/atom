Address = require './address'

module.exports =
class CurrentSelectionAddress extends Address
  getRange: (buffer, range) ->
    range

  isRelative: -> true
