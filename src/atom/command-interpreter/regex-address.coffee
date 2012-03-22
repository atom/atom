Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class RegexAddress extends Address
  regex: null

  constructor: (pattern) ->
    @regex = new RegExp(pattern)

  getRange: (editor) ->
    selectedRange = editor.getSelection().getBufferRange()
    rangeToSearch = new Range(selectedRange.end, editor.getEofPosition())
    text = editor.getTextInRange(rangeToSearch)

    if match = text.match(@regex)
      buffer = editor.buffer
      startIndex = buffer.characterIndexForPosition(rangeToSearch.start) + match.index
      endIndex = startIndex + match[0].length

      startPosition = buffer.positionForCharacterIndex(startIndex)
      endPosition = buffer.positionForCharacterIndex(endIndex)

      return new Range(startPosition, endPosition)
    else
      return selectedRange