Command = require 'command-interpreter/command'

module.exports =
class Substitution extends Command
  global: false

  constructor: (@findText, @replaceText, @options) ->
    @findRegex = new RegExp(@findText, 'mg')
    @global = 'g' in @options

  execute: (editor) ->
    selectedText = editor.getSelectedText()
    selectionStartIndex = editor.buffer.characterIndexForPosition(editor.getSelection().getBufferRange().start)

    buffer = editor.buffer
    range = editor.getSelection().getBufferRange()
    startIndex = buffer.characterIndexForPosition(range.start)
    endIndex = buffer.characterIndexForPosition(range.end)

    @replace(editor, buffer.getText(), startIndex, endIndex)

  replace: (editor, text, startIndex, endIndex, lengthDelta=0) ->
    @findRegex.lastIndex = startIndex
    return unless match = @findRegex.exec(text)

    matchLength = match[0].length
    matchStartIndex = match.index
    matchEndIndex = match.index + matchLength

    return if matchEndIndex > endIndex

    buffer = editor.buffer
    startPosition = buffer.positionForCharacterIndex(matchStartIndex + lengthDelta)
    endPosition = buffer.positionForCharacterIndex(matchEndIndex + lengthDelta)

    buffer.change([startPosition, endPosition], @replaceText)

    if matchLength is 0
      matchStartIndex++
      matchEndIndex++

    if @global
      @replace(editor, text, matchEndIndex, endIndex, lengthDelta + @replaceText.length - matchLength)

