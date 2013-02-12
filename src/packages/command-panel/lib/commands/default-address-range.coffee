Address = require './address'

module.exports =
class DefaultAddressRange extends Address
  getRange: (buffer, range)->
    if range.isEmpty()
      buffer.getRange()
    else
      range

  isRelative: -> false
