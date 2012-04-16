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
    @currentBuffer = buffer
    @currentBuffer.on 'change', => @buildWordList()
    @buildWordList()

  buildWordList: () ->
    @wordList = _.unique(@currentBuffer.getText().match(@wordRegex))

  completeWordAtEditorCursorPosition: () ->
    position = @editor.getCursorBufferPosition()
    lineRange = [[position.row, 0], [position.row, @editor.lineLengthForBufferRow(position.row)]]
    [prefix, suffix] = ["", ""]

    @currentBuffer.scanInRange @wordRegex, lineRange, (match, range, {stop}) ->
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
    regex.exec(word) for word in @wordList when regex.test(word)
