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
    @bracketAnchorRanges = []

    _.adviseBefore @editSession, 'insertText', (text) =>
      return true if @editSession.hasMultipleCursors()

      cursorBufferPosition = @editSession.getCursorBufferPosition()
      nextCharachter = @editSession.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0,1])])

      autoCompleteOpeningBracket = @isOpeningBracket(text) and /\W|^$/.test(nextCharachter)
      skipOverExistingClosingBracket = false
      if @isClosingBracket(text) and nextCharachter == text
        if bracketAnchorRange = @bracketAnchorRanges.filter((anchorRange) -> anchorRange.getBufferRange().end.isEqual(cursorBufferPosition))[0]
          skipOverExistingClosingBracket = true

      if skipOverExistingClosingBracket
        bracketAnchorRange.destroy()
        _.remove(@bracketAnchorRanges, bracketAnchorRange)
        @editSession.moveCursorRight()
        false
      else if autoCompleteOpeningBracket
        @editSession.insertText(text + @pairedCharacters[text])
        @editSession.moveCursorLeft()
        range = [cursorBufferPosition, cursorBufferPosition.add([0, text.length])]
        @bracketAnchorRanges.push @editSession.addAnchorRange(range)
        false

  isOpeningBracket: (string) ->
    @pairedCharacters[string]?

  isClosingBracket: (string) ->
    @getInvertedPairedCharacters()[string]?

  getInvertedPairedCharacters: ->
    return @invertedPairedCharacters if @invertedPairedCharacters

    @invertedPairedCharacters = {}
    for open, close of @pairedCharacters
      @invertedPairedCharacters[close] = open
    @invertedPairedCharacters

  toggleLineCommentsInRange: (range) ->
    range = Range.fromObject(range)
    scopes = @tokenizedBuffer.scopesForPosition(range.start)
    return unless commentString = TextMateBundle.lineCommentStringForScope(scopes[0])

    commentRegexString = _.escapeRegExp(commentString)
    commentRegexString = commentRegexString.replace(/(\s+)$/, '($1)?')
    commentRegex = new OnigRegExp("^\s*#{commentRegexString}")

    shouldUncomment = commentRegex.test(@editSession.lineForBufferRow(range.start.row))

    for row in [range.start.row..range.end.row]
      line = @editSession.lineForBufferRow(row)
      if shouldUncomment
        if match = commentRegex.search(line)
          @editSession.buffer.change([[row, 0], [row, match[0].length]], "")
      else
        @editSession.buffer.insert([row, 0], commentString)

  doesBufferRowStartFold: (bufferRow) ->
    return false if @editSession.isBufferRowBlank(bufferRow)
    nextNonEmptyRow = @editSession.nextNonBlankBufferRow(bufferRow)
    return false unless nextNonEmptyRow?
    @editSession.indentationForBufferRow(nextNonEmptyRow) > @editSession.indentationForBufferRow(bufferRow)

  rowRangeForFoldAtBufferRow: (bufferRow) ->
    return null unless @doesBufferRowStartFold(bufferRow)

    startIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    scopes = @tokenizedBuffer.scopesForPosition([bufferRow, 0])
    for row in [(bufferRow + 1)..@editSession.getLastBufferRow()]
      continue if @editSession.isBufferRowBlank(row)
      indentation = @editSession.indentationForBufferRow(row)
      if indentation <= startIndentLevel
        includeRowInFold = indentation == startIndentLevel and TextMateBundle.foldEndRegexForScope(@grammar, scopes[0]).search(@editSession.lineForBufferRow(row))
        foldEndRow = row if includeRowInFold
        break

      foldEndRow = row

    [bufferRow, foldEndRow]

  suggestedIndentForBufferRow: (bufferRow) ->
    currentIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    scopes = @tokenizedBuffer.scopesForPosition([bufferRow, 0])
    return currentIndentLevel unless increaseIndentPattern = TextMateBundle.indentRegexForScope(scopes[0])

    currentLine = @buffer.lineForRow(bufferRow)
    precedingRow = @buffer.previousNonBlankRow(bufferRow)
    return currentIndentLevel unless precedingRow?

    precedingLine = @buffer.lineForRow(precedingRow)

    desiredIndentLevel = @editSession.indentationForBufferRow(precedingRow)
    desiredIndentLevel += 1 if increaseIndentPattern.test(precedingLine)

    return desiredIndentLevel unless decreaseIndentPattern = TextMateBundle.outdentRegexForScope(scopes[0])
    desiredIndentLevel -= 1 if decreaseIndentPattern.test(currentLine)

    Math.max(desiredIndentLevel, currentIndentLevel)

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
    increaseIndentPattern = TextMateBundle.indentRegexForScope(scopes[0])
    return unless increaseIndentPattern

    currentIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    desiredIndentLevel = @editSession.indentationForBufferRow(precedingRow)
    desiredIndentLevel += 1 if increaseIndentPattern.test(precedingLine)
    if desiredIndentLevel > currentIndentLevel
      @editSession.setIndentationForBufferRow(bufferRow, desiredIndentLevel)

  autoDecreaseIndentForBufferRow: (bufferRow) ->
    scopes = @tokenizedBuffer.scopesForPosition([bufferRow, 0])
    increaseIndentPattern = TextMateBundle.indentRegexForScope(scopes[0])
    decreaseIndentPattern = TextMateBundle.outdentRegexForScope(scopes[0])
    return unless increaseIndentPattern and decreaseIndentPattern

    line = @buffer.lineForRow(bufferRow)
    return unless decreaseIndentPattern.test(line)

    currentIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    precedingRow = @buffer.previousNonBlankRow(bufferRow)
    precedingLine = @buffer.lineForRow(precedingRow)

    desiredIndentLevel = @editSession.indentationForBufferRow(precedingRow)
    desiredIndentLevel -= 1 unless increaseIndentPattern.test(precedingLine)
    if desiredIndentLevel < currentIndentLevel
      @editSession.setIndentationForBufferRow(bufferRow, desiredIndentLevel)

  getLineTokens: (line, stack) ->
    {tokens, stack} = @grammar.getLineTokens(line, stack)

