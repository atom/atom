Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class RegexAddress extends Address
  regex: null
  reverse: null

  constructor: (pattern, reverse) ->
    @reverse = reverse
    @regex = new RegExp(pattern)

  getRange: (editor, currentRange) ->
    rangeBefore = new Range([0, 0], currentRange.end)
    rangeAfter = new Range(currentRange.end, editor.getEofPosition())

    rangeToSearch = if @reverse then rangeBefore else rangeAfter

    rangeToReturn = null
    scanMethodName = if @reverse then "backwardsScanInRange" else "scanInRange"
    editor[scanMethodName] @regex, rangeToSearch, (match, range) ->
      rangeToReturn = range

    if rangeToReturn
      rangeToReturn
    else
      rangeToSearch = if @reverse then rangeAfter else rangeBefore
      editor[scanMethodName] @regex, rangeToSearch, (match, range) ->
        rangeToReturn = range

      rangeToReturn or currentRange

  isRelative: -> true
