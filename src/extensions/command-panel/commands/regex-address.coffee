Address = require 'command-panel/commands/address'
Range = require 'range'

module.exports =
class RegexAddress extends Address
  regex: null
  reverse: null

  constructor: (pattern, isReversed) ->
    @isReversed = isReversed
    @regex = new RegExp(pattern)

  getRange: (buffer, range) ->
    rangeBefore = new Range([0, 0], range.start)
    rangeAfter = new Range(range.end, buffer.getEofPosition())

    rangeToSearch = if @isReversed then rangeBefore else rangeAfter

    rangeToReturn = null
    scanMethodName = if @isReversed then "backwardsScanInRange" else "scanInRange"
    buffer[scanMethodName] @regex, rangeToSearch, (match, range) ->
      rangeToReturn = range

    if rangeToReturn
      rangeToReturn
    else
      rangeToSearch = if @isReversed then rangeAfter else rangeBefore
      buffer[scanMethodName] @regex, rangeToSearch, (match, range) ->
        rangeToReturn = range

      rangeToReturn or range

  isRelative: -> true

  reverse: ->
    new RegexAddress(@regex, !@isReversed)
