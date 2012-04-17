{View, $$} = require 'space-pen'
_ = require 'underscore'
Range = require 'range'

module.exports =
class Autocomplete extends View
  @content: ->
    @div class: 'autocomplete', =>
      @ol outlet: 'matchesList'

  editor: null
  currentBuffer: null
  wordList = null
  wordRegex: /\w+/g

  initialize: (@editor) ->
    @setCurrentBuffer(@editor.buffer)
    @editor.on 'autocomplete:complete-word', => @completeWordAtEditorCursorPosition()
    @editor.on 'buffer-path-change', => @setCurrentBuffer(@editor.buffer)

  setCurrentBuffer: (buffer) ->
    @currentBuffer.off '.autocomplete' if @currentBuffer
    @currentBuffer = buffer
    @currentBuffer.on 'change.autocomplete', => @buildWordList()
    @buildWordList()

  buildWordList: () ->
    @wordList = _.unique(@currentBuffer.getText().match(@wordRegex))

  completeWord: ->
    selection = @editor.getSelection()
    {prefix, suffix} = @prefixAndSuffixOfSelection(selection)
    currentWord = prefix + @editor.getSelectedText() + suffix

    for match in @wordMatches(prefix, suffix) when match[0] != currentWord
      startPosition = selection.getBufferRange().start
      @editor.insertText(match[1])
      @editor.setSelectionBufferRange([startPosition, [startPosition.row, startPosition.column + match[1].length]])
      break

  prefixAndSuffixOfSelection: (selection) ->
    selectionRange = selection.getBufferRange()
    lineRange = [[selectionRange.start.row, 0], [selectionRange.end.row, @editor.lineLengthForBufferRow(selectionRange.end.row)]]
    [prefix, suffix] = ["", ""]

    @currentBuffer.scanInRange @wordRegex, lineRange, (match, range, {stop}) ->
      if range.intersectsWith(selectionRange)
        prefixOffset = selectionRange.start.column - range.start.column
        suffixOffset = selectionRange.end.column - range.end.column

        if range.start.isLessThan(selectionRange.start)
          prefix = match[0][0...prefixOffset]

        if range.end.isGreaterThan(selectionRange.end)
          suffix = match[0][suffixOffset..]
          stop()

    {prefix, suffix}

  wordMatches: (prefix, suffix) ->
    regex = new RegExp("^#{prefix}(.+)#{suffix}$", "i")
    regex.exec(word) for word in @wordList when regex.test(word)
