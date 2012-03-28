Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class RegexAddress extends Address
  regex: null

  constructor: (pattern) ->
    @regex = new RegExp(pattern)

  getRange: (editor) ->
    selectedRange = editor.getLastSelectionInBuffer().getBufferRange()
    rangeToSearch = new Range(selectedRange.end, editor.getEofPosition())

    rangeToReturn = selectedRange
    editor.buffer.traverseRegexMatchesInRange @regex, rangeToSearch, (match, range) ->
      rangeToReturn = range

    rangeToReturn

  isRelative: -> true
