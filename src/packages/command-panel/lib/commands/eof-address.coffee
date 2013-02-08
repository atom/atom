Address = require './address'
Range = require 'range'

module.exports =
class EofAddress extends Address
  getRange: (buffer, range) ->
    eof = buffer.getEofPosition()
    new Range(eof, eof)

  isRelative: -> false
