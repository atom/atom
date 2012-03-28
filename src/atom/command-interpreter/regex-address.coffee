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

    rangeToReturn = null
    editor.buffer.traverseRegexMatchesInRange @regex, rangeToSearch, (match, range) ->
      rangeToReturn = range

    if rangeToReturn
      rangeToReturn
    else
      rangeToSearch = new Range([0, 0], rangeToSearch.start)
      editor.buffer.traverseRegexMatchesInRange @regex, rangeToSearch, (match, range) ->
        rangeToReturn = range

      rangeToReturn or selectedRange

  isRelative: -> true
