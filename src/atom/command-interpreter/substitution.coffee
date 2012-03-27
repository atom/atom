Command = require 'command-interpreter/command'

module.exports =
class Substitution extends Command
  global: false

  constructor: (@findText, @replaceText, @options) ->
    @findRegex = @regexForPattern(@findText)
    @global = 'g' in @options

  execute: (editor) ->
    selectedText = editor.getSelectedText()
    selectionStartIndex = editor.buffer.characterIndexForPosition(editor.getSelection().getBufferRange().start)

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
      offset = if match[0].length then 0 else 1
      startNextStringFragmentAt = match.index + match[0].length + offset
      return if startNextStringFragmentAt >= text.length
      text = text[startNextStringFragmentAt..]
      startIndex = matchStartIndex + offset + @replaceText.length
      @replace(editor, text, startIndex)

