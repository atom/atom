Address = require 'command-panel/src/commands/address'
Range = require 'range'

module.exports =
class AllLinesAddress extends Address
    getRange: (buffer)->
      buffer.getRange()

    isRelative: -> false
