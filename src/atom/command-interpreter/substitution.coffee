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

  replace: (editor, text, globalStartIndex) ->
    return unless match = text.match(@findRegex)

    localMatchStartIndex = match.index
    localMatchEndIndex = localMatchStartIndex + match[0].length

    globalMatchStartIndex = globalStartIndex + localMatchStartIndex
    globalMatchEndIndex = globalStartIndex + localMatchEndIndex

    buffer = editor.buffer
    startPosition = buffer.positionForCharacterIndex(globalMatchStartIndex)
    endPosition = buffer.positionForCharacterIndex(globalMatchEndIndex)
    buffer.change([startPosition, endPosition], @replaceText)

    if match[0].length is 0
      localMatchEndIndex++
      globalMatchStartIndex++

    if @global
      return if localMatchStartIndex >= text.length
      text = text[localMatchEndIndex..]
      nextGlobalStartIndex = globalMatchStartIndex + @replaceText.length
      @replace(editor, text, nextGlobalStartIndex)

