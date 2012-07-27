AceAdaptor = require 'ace-adaptor'
Range = require 'range'
_ = require 'underscore'

module.exports =
class LanguageMode
  matchingCharacters:
    '(': ')'
    '[': ']'
    '{': '}'
    '"': '"'
    "'": "'"

  constructor: (@editSession) ->
    @buffer = @editSession.buffer
    @aceMode = @requireAceMode()
    @aceAdaptor = new AceAdaptor(@editSession)

    _.adviseBefore @editSession, 'insertText', (text) =>
      if matchingCharacter = @matchingCharacters[text]
        @editSession.insertText text + matchingCharacter
        @editSession.moveCursorLeft()
        false

  requireAceMode: (fileExtension) ->
    modeName = switch @editSession.buffer.getExtension()
      when 'js' then 'javascript'
      when 'coffee' then 'coffee'
      when 'rb', 'ru' then 'ruby'
      when 'c', 'h', 'cpp' then 'c_cpp'
      when 'html', 'htm' then 'html'
      when 'css' then 'css'
      when 'java' then 'java'
      when 'xml' then 'xml'
      else 'text'
    new (require("ace/mode/#{modeName}").Mode)

  toggleLineCommentsInRange: (range) ->
    range = Range.fromObject(range)
    @aceMode.toggleCommentLines(@tokenizedBuffer.stateForRow(range.start.row), @aceAdaptor, range.start.row, range.end.row)

  isBufferRowFoldable: (bufferRow) ->
    @aceMode.foldingRules?.getFoldWidget(@aceAdaptor, null, bufferRow) == "start"

  rowRangeForFoldAtBufferRow: (bufferRow) ->
    if aceRange = @aceMode.foldingRules?.getFoldWidgetRange(@aceAdaptor, null, bufferRow)
      [aceRange.start.row, aceRange.end.row]
    else
      null

  indentationForRow: (row) ->
    state = @tokenizedBuffer.stateForRow(row)
    previousRowText = @buffer.lineForRow(row - 1)
    @aceMode.getNextLineIndent(state, previousRowText, @editSession.tabText)

  autoIndentTextAfterBufferPosition: (text, bufferPosition) ->
    { row, column} = bufferPosition
    state = @tokenizedBuffer.stateForRow(row)
    lineBeforeCursor = @buffer.lineForRow(row)[0...column]
    if text[0] == "\n"
      indent = @aceMode.getNextLineIndent(state, lineBeforeCursor, @editSession.tabText)
      text = text[0] + indent + text[1..]
    else if @aceMode.checkOutdent(state, lineBeforeCursor, text)
      shouldOutdent = true

    {text, shouldOutdent}

  autoOutdentBufferRow: (bufferRow) ->
    state = @tokenizedBuffer.stateForRow(bufferRow)
    @aceMode.autoOutdent(state, @aceAdaptor, bufferRow)

  getLineTokens: (line, state) ->
    {tokens, state} = @aceMode.getTokenizer().getLineTokens(line, state)

