module.exports =
class Substitution
  constructor: (@findText, @replaceText) ->
    @findRegex = new RegExp(@findText)

  perform: (editor) ->
    { buffer } = editor
    selectedText = editor.getSelectedText()

    selectionStartIndex = buffer.characterIndexForPosition(editor.getSelection().getBufferRange().start)

    match = @findRegex.exec(selectedText)
    matchStartIndex = selectionStartIndex + match.index
    matchEndIndex = matchStartIndex + match[0].length

    startPosition = buffer.positionForCharacterIndex(matchStartIndex)
    endPosition = buffer.positionForCharacterIndex(matchEndIndex)

    buffer.change([startPosition, endPosition], @replaceText)
