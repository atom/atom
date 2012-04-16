_ = require 'underscore'
Range = require 'range'

module.exports =
class Autocomplete
  editor: null
  currentBuffer: null
  wordList = null
  wordRegex: /\w+/g

  constructor: (@editor) ->
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

  completeWordAtEditorCursorPosition: () ->
    selectionRange = @editor.getSelection().getBufferRange()
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

    for match in @matches(prefix, suffix)
      continue if match[0] == prefix + @editor.getSelectedText() + suffix
      startPosition = @editor.getSelection().getBufferRange().start
      @editor.insertText(match[1])
      @editor.setSelectionBufferRange([startPosition, [startPosition.row, startPosition.column + match[1].length]])
      break

  matches: (prefix, suffix) ->
    regex = new RegExp("^#{prefix}(.+)#{suffix}$", "i")
    regex.exec(word) for word in @wordList when regex.test(word)
