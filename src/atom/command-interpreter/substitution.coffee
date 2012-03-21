module.exports =
class Substitution
  global: false

  constructor: (@findText, @replaceText, @options) ->
    @findRegex = new RegExp(@findText, "g")
    @global = 'g' in @options

  perform: (editor) ->
    { buffer } = editor
    selectedText = editor.getSelectedText()
    selectionStartIndex = buffer.characterIndexForPosition(editor.getSelection().getBufferRange().start)

    while match = @findRegex.exec(selectedText)
      matchStartIndex = selectionStartIndex + match.index
      matchEndIndex = matchStartIndex + match[0].length

      startPosition = buffer.positionForCharacterIndex(matchStartIndex)
      endPosition = buffer.positionForCharacterIndex(matchEndIndex)

      buffer.change([startPosition, endPosition], @replaceText)
      break unless @global
      selectedText = editor.getSelectedText()
