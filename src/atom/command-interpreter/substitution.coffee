module.exports =
class Substitution
  global: false

  constructor: (@findText, @replaceText, @options) ->
    @findRegex = new RegExp(@findText)
    @global = 'g' in @options

  execute: (editor) ->
    selectedText = editor.getSelectedText()
    selectionStartIndex = editor.buffer.characterIndexForPosition(editor.getSelection().getBufferRange().start)
    selectionEndIndex = selectionStartIndex + selectedText.length

    @replace(editor, selectedText, selectionStartIndex)

  replace: (editor, text, startIndex) ->
    return unless match = text.match(@findRegex)

    matchStartIndex = startIndex + match.index
    matchEndIndex = matchStartIndex + match[0].length

    buffer = editor.buffer
    startPosition = buffer.positionForCharacterIndex(matchStartIndex)
    endPosition = buffer.positionForCharacterIndex(matchEndIndex)

    buffer.change([startPosition, endPosition], @replaceText)

    if @global
      text = text[(match.index + match[0].length)..]
      startIndex = matchStartIndex + @replaceText.length
      @replace(editor, text, startIndex)
