Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class RegexAddress extends Address
  regex: null
  reverse: null

  constructor: (pattern, isReversed) ->
    @isReversed = isReversed
    @regex = new RegExp(pattern)

  getRange: (editor, currentRange) ->
    rangeBefore = new Range([0, 0], currentRange.start)
    rangeAfter = new Range(currentRange.end, editor.getEofPosition())

    rangeToSearch = if @isReversed then rangeBefore else rangeAfter

    rangeToReturn = null
    scanMethodName = if @isReversed then "backwardsScanInRange" else "scanInRange"
    editor[scanMethodName] @regex, rangeToSearch, (match, range) ->
      rangeToReturn = range

    if rangeToReturn
      rangeToReturn
    else
      rangeToSearch = if @isReversed then rangeAfter else rangeBefore
      editor[scanMethodName] @regex, rangeToSearch, (match, range) ->
        rangeToReturn = range

      rangeToReturn or currentRange

  isRelative: -> true

  reverse: ->
    new RegexAddress(@regex, !@isReversed)