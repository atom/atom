Command = require 'command-interpreter/command'
Range = require 'range'

module.exports =
class SelectAllMatches extends Command
  @regex: null

  constructor: (pattern) ->
    @regex = @regexForPattern(pattern)

  execute: (editor) ->
    rangesToSelect = []
    for selection in editor.getSelections()
      selectedText = selection.getText()
      selectionStartIndex = editor.buffer.characterIndexForPosition(selection.getBufferRange().start)
      for range in @findMatchingRanges(editor, selectedText, selectionStartIndex)
        rangesToSelect.push(range)

    editor.clearSelections()
    editor.addSelectionForBufferRange(range) for range in rangesToSelect

  findMatchingRanges: (editor, text, startIndex) ->
    return [] unless match = text.match(@regex)

    matchStartIndex = startIndex + match.index
    matchEndIndex = matchStartIndex + match[0].length

    buffer = editor.buffer
    startPosition = buffer.positionForCharacterIndex(matchStartIndex)
    endPosition = buffer.positionForCharacterIndex(matchEndIndex)
    range = new Range(startPosition, endPosition)

    text = text[(match.index + match[0].length)..]
    startIndex = matchEndIndex
    [range].concat(@findMatchingRanges(editor, text, startIndex))

