Address = require './address'
{Range} = require 'telepath'

module.exports =
class ZeroAddress extends Address
  getRange: ->
    new Range([0, 0], [0, 0])

  isRelative: -> false
