_ = require 'underscore'
Range = require 'range'

module.exports =
class Autocomplete
  editor: null
  wordListForBufferId = null
  wordRegex: /\w+/g

  constructor: (@editor) ->
    @wordListForBufferId = {}
    @buildWordListForBuffer(@editor.buffer)
    @editor.on 'autocomplete:complete-word', => @completeWordAtEditorCursorPosition()
    @editor.on 'buffer-path-change', => @buildWordListForBuffer(editor.buffer)
    @editor.buffer.on 'change', => @buildWordListForBuffer(@editor.buffer)

  buildWordListForBuffer: (buffer) ->
    @wordListForBufferId[buffer.id] = _.unique(buffer.getText().match(@wordRegex))

  completeWordAtEditorCursorPosition: () ->
    position = @editor.getCursorBufferPosition()
    lineRange = [[position.row, 0], [position.row, @editor.lineLengthForBufferRow(position.row)]]
    [prefix, suffix] = ["", ""]

    @editor.buffer.scanInRange @wordRegex, lineRange, (match, range, {stop}) ->
      if range.start.isLessThan(position)
        if range.end.isEqual(position)
          prefix = match[0]
        else if range.end.isGreaterThan(position)
          index = position.column - range.start.column
          prefix = match[0][0...index]
          suffix = match[0][index..]
          stop()
      else if range.start.isEqual(position)
        suffix = match[0]
        stop()

    if match = @matches(prefix, suffix)[0]
      @editor.insertText(match[1])

  matches: (prefix, suffix) ->
    regex = new RegExp("^#{prefix}(.+)#{suffix}$", "i")
    wordList = @wordListForBufferId[@editor.buffer.id]
    regex.exec(word) for word in wordList when regex.test(word)
