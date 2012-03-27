Command = require 'command-interpreter/command'
Range = require 'range'

module.exports =
class SelectAllMatches extends Command
  @regex: null

  constructor: (pattern) ->
    @regex = new RegExp(pattern)

  execute: (editor) ->
    selectedText = editor.getSelectedText()
    selectionStartIndex = editor.buffer.characterIndexForPosition(editor.getSelection().getBufferRange().start)

    matchingRanges = @findMatchingRanges(editor, selectedText, selectionStartIndex)
    return unless matchingRanges.length
    editor.setSelectionBufferRange(matchingRanges[0])
    editor.addSelectionForBufferRange(range) for range in matchingRanges[1..]


  findMatchingRanges: (editor, text, startIndex) ->
    console.log text
    return [] unless match = text.match(@regex)

    console.log match
    console.log match[0]

    matchStartIndex = startIndex + match.index
    matchEndIndex = matchStartIndex + match[0].length

    buffer = editor.buffer
    startPosition = buffer.positionForCharacterIndex(matchStartIndex)
    endPosition = buffer.positionForCharacterIndex(matchEndIndex)
    range = new Range(startPosition, endPosition)

    text = text[(match.index + match[0].length)..]
    startIndex = matchEndIndex
    [range].concat(@findMatchingRanges(editor, text, startIndex))

