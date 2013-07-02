Address = require './address'
{Range} = require 'telepath'

module.exports =
class RegexAddress extends Address
  regex: null
  isReversed: false

  constructor: (@pattern, isReversed, options) ->
    flags = ""
    pattern = pattern.source if pattern.source

    patternContainsCapitalLetter = /(^|[^\\])[A-Z]/.test(pattern)
    flags += "i" unless patternContainsCapitalLetter
    @isReversed = isReversed

    @regex = new RegExp(pattern, flags)

  getRange: (buffer, range) ->
    rangeBefore = new Range([0, 0], range.start)
    rangeAfter = new Range(range.end, buffer.getEofPosition())

    rangeToSearch = if @isReversed then rangeBefore else rangeAfter

    rangeToReturn = null
    scanMethodName = if @isReversed then "backwardsScanInRange" else "scanInRange"
    buffer[scanMethodName] @regex, rangeToSearch, ({range}) ->
      rangeToReturn = range

    if not rangeToReturn
      rangeToSearch = if @isReversed then rangeAfter else rangeBefore
      buffer[scanMethodName] @regex, rangeToSearch, ({range}) ->
        rangeToReturn = range

    if not rangeToReturn
      flags = ""
      flags += "i" if @regex.ignoreCase
      flags += "g" if @regex.global
      flags += "m" if @regex.multiline
      @errorMessage = "Pattern not found /#{@regex.source}/#{flags}"

    rangeToReturn or range

  isRelative: -> true

  reverse: ->
    new RegexAddress(@regex, !@isReversed)
