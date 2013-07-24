Address = require './address'
{Range} = require 'telepath'

module.exports =
class EofAddress extends Address
  getRange: (buffer, range) ->
    eof = buffer.getEofPosition()
    new Range(eof, eof)

  isRelative: -> false
