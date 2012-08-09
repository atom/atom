Range = require 'range'
TextMateBundle = require 'text-mate-bundle'
_ = require 'underscore'
require 'underscore-extensions'

module.exports =
class LanguageMode
  pairedCharacters:
    '(': ')'
    '[': ']'
    '{': '}'
    '"': '"'
    "'": "'"

  constructor: (@editSession) ->
    @buffer = @editSession.buffer
    @grammar = TextMateBundle.grammarForFileName(@buffer.getBaseName())

    _.adviseBefore @editSession, 'insertText', (text) =>
      return true if @editSession.hasMultipleCursors()

      cursorBufferPosition = @editSession.getCursorBufferPosition()
      nextCharachter = @editSession.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0, 1])])

      if @isCloseBracket(text) and text == nextCharachter
        @editSession.moveCursorRight()
        false
      else if pairedCharacter = @pairedCharacters[text]
        @editSession.insertText text + pairedCharacter
        @editSession.moveCursorLeft()
        false

  isOpenBracket: (string) ->
    @pairedCharacters[string]?

  isCloseBracket: (string) ->
    @getInvertedPairedCharacters()[string]?

  getInvertedPairedCharacters: ->
    return @invertedPairedCharacters if @invertedPairedCharacters

    @invertedPairedCharacters = {}
    for open, close of @pairedCharacters
      @invertedPairedCharacters[close] = open
    @invertedPairedCharacters

  toggleLineCommentsInRange: (range) ->
    selectedBufferRanges = @editSession.getSelectedBufferRanges()
    range = Range.fromObject(range)
    range = new Range([range.start.row, 0], [range.end.row, Infinity])
    scopes = @tokenizedBuffer.scopesForPosition(range.start)
    commentString = TextMateBundle.lineCommentStringForScope(scopes[0])
    commentSource = "^(\s*)" + _.escapeRegExp(commentString)

    text = @editSession.getTextInBufferRange(range)
    isCommented = new RegExp(commentSource).test text

    if isCommented
      text = text.replace(new RegExp(commentSource, "gm"), "$1")
    else
      text = text.replace(/^/gm, commentString)

    @editSession.setTextInBufferRange(range, text)
    @editSession.setSelectedBufferRanges(selectedBufferRanges)

  doesBufferRowStartFold: (bufferRow) ->
    return false if @editSession.isBufferRowBlank(bufferRow)
    nextNonEmptyRow = @editSession.nextNonBlankBufferRow(bufferRow)
    return false unless nextNonEmptyRow?
    @editSession.indentationForBufferRow(nextNonEmptyRow) > @editSession.indentationForBufferRow(bufferRow)

  rowRangeForFoldAtBufferRow: (bufferRow) ->
    return null unless @doesBufferRowStartFold(bufferRow)

    startIndentation = @editSession.indentationForBufferRow(bufferRow)
    for row in [(bufferRow + 1)..@editSession.getLastBufferRow()]
      continue if @editSession.isBufferRowBlank(row)
      indentation = @editSession.indentationForBufferRow(row)
      if indentation <= startIndentation
        includeRowInFold = indentation == startIndentation and @grammar.foldEndRegex.search(@editSession.lineForBufferRow(row))
        foldEndRow = row if includeRowInFold
        break

      foldEndRow = row

    [bufferRow, foldEndRow]


  autoIndentBufferRows: (startRow, endRow) ->
    @autoIndentBufferRow(row) for row in [startRow..endRow]

  autoIndentBufferRow: (bufferRow) ->
    @autoIncreaseIndentForBufferRow(bufferRow)
    @autoDecreaseIndentForBufferRow(bufferRow)

  autoIncreaseIndentForBufferRow: (bufferRow) ->
    precedingRow = @buffer.previousNonBlankRow(bufferRow)
    return unless precedingRow?

    precedingLine = @editSession.lineForBufferRow(precedingRow)
    scopes = @tokenizedBuffer.scopesForPosition([precedingRow, Infinity])
    increaseIndentPattern = new OnigRegExp(TextMateBundle.getPreferenceInScope(scopes[0], 'increaseIndentPattern'))

    currentIndentation = @buffer.indentationForRow(bufferRow)
    desiredIndentation = @buffer.indentationForRow(precedingRow)
    desiredIndentation += @editSession.tabText.length if increaseIndentPattern.test(precedingLine)
    if desiredIndentation > currentIndentation
      @buffer.setIndentationForRow(bufferRow, desiredIndentation)

  autoDecreaseIndentForBufferRow: (bufferRow) ->
    scopes = @tokenizedBuffer.scopesForPosition([bufferRow, 0])
    increaseIndentPattern = new OnigRegExp(TextMateBundle.getPreferenceInScope(scopes[0], 'increaseIndentPattern'))
    decreaseIndentPattern = new OnigRegExp(TextMateBundle.getPreferenceInScope(scopes[0], 'decreaseIndentPattern'))
    line = @buffer.lineForRow(bufferRow)
    return unless decreaseIndentPattern.test(line)

    currentIndentation = @buffer.indentationForRow(bufferRow)
    precedingRow = @buffer.previousNonBlankRow(bufferRow)
    precedingLine = @buffer.lineForRow(precedingRow)

    desiredIndentation = @buffer.indentationForRow(precedingRow)
    desiredIndentation -= @editSession.tabText.length unless increaseIndentPattern.test(precedingLine)
    if desiredIndentation < currentIndentation
      @buffer.setIndentationForRow(bufferRow, desiredIndentation)

  getLineTokens: (line, stack) ->
    {tokens, stack} = @grammar.getLineTokens(line, stack)

