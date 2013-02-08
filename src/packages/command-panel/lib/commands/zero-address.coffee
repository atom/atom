Address = require './address'
Range = require 'range'

module.exports =
class ZeroAddress extends Address
  getRange: ->
    new Range([0, 0], [0, 0])

  isRelative: -> false
