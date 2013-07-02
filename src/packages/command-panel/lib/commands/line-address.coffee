Address = require './address'
{Range} = require 'telepath'

module.exports =
class LineAddress extends Address
  constructor: (lineNumber) ->
    @row = lineNumber - 1

  getRange: ->
    new Range([@row, 0], [@row + 1, 0])

  isRelative: -> false
