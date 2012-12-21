Range = require 'range'
TextMateBundle = require 'text-mate-bundle'
_ = require 'underscore'
require 'underscore-extensions'

module.exports =
class LanguageMode
  buffer = null
  grammar = null
  editSession = null
  pairedCharacters:
    '(': ')'
    '[': ']'
    '{': '}'
    '"': '"'
    "'": "'"

  constructor: (@editSession) ->
    @buffer = @editSession.buffer
    @grammar = TextMateBundle.grammarForFilePath(@buffer.getPath())
    @bracketAnchorRanges = []

    _.adviseBefore @editSession, 'insertText', (text) =>
      return true if @editSession.hasMultipleCursors()

      cursorBufferPosition = @editSession.getCursorBufferPosition()
      previousCharachter = @editSession.getTextInBufferRange([cursorBufferPosition.add([0, -1]), cursorBufferPosition])
      nextCharachter = @editSession.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0,1])])

      hasWordAfterCursor = /\w/.test(nextCharachter)
      hasWordBeforeCursor = /\w/.test(previousCharachter)

      autoCompleteOpeningBracket = @isOpeningBracket(text) and not hasWordAfterCursor and not (@isQuote(text) and hasWordBeforeCursor)
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

  isQuote: (string) ->
    /'|"/.test(string)

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

  toggleLineCommentsForBufferRows: (start, end) ->
    scopes = @editSession.scopesForBufferPosition([start, 0])
    return unless commentStartString = TextMateBundle.lineCommentStartStringForScope(scopes[0])

    buffer = @editSession.buffer
    commentStartRegexString = _.escapeRegExp(commentStartString).replace(/(\s+)$/, '($1)?')
    commentStartRegex = new OnigRegExp("^(\\s*)(#{commentStartRegexString})")
    shouldUncomment = commentStartRegex.test(buffer.lineForRow(start))

    if commentEndString = TextMateBundle.lineCommentEndStringForScope(scopes[0])
      if shouldUncomment
        commentEndRegexString = _.escapeRegExp(commentEndString).replace(/^(\s+)/, '($1)?')
        commentEndRegex = new OnigRegExp("(#{commentEndRegexString})(\\s*)$")
        startMatch =  commentStartRegex.search(buffer.lineForRow(start))
        endMatch = commentEndRegex.search(buffer.lineForRow(end))
        if startMatch and endMatch
          buffer.transact ->
            columnStart = startMatch[1].length
            columnEnd = columnStart + startMatch[2].length
            buffer.change([[start, columnStart], [start, columnEnd]], "")

            endLength = buffer.lineLengthForRow(end) - endMatch[2].length
            endColumn = endLength - endMatch[1].length
            buffer.change([[end, endColumn], [end, endLength]], "")
      else
        buffer.transact ->
          buffer.insert([start, 0], commentStartString)
          buffer.insert([end, buffer.lineLengthForRow(end)], commentEndString)
    else
      if shouldUncomment
        for row in [start..end]
          if match = commentStartRegex.search(buffer.lineForRow(row))
            columnStart = match[1].length
            columnEnd = columnStart + match[2].length
            buffer.change([[row, columnStart], [row, columnEnd]], "")
      else
        for row in [start..end]
          buffer.insert([row, 0], commentStartString)

  doesBufferRowStartFold: (bufferRow) ->
    return false if @editSession.isBufferRowBlank(bufferRow)
    nextNonEmptyRow = @editSession.nextNonBlankBufferRow(bufferRow)
    return false unless nextNonEmptyRow?
    @editSession.indentationForBufferRow(nextNonEmptyRow) > @editSession.indentationForBufferRow(bufferRow)

  rowRangeForFoldAtBufferRow: (bufferRow) ->
    return null unless @doesBufferRowStartFold(bufferRow)

    startIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    scopes = @editSession.scopesForBufferPosition([bufferRow, 0])
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
    scopes = @editSession.scopesForBufferPosition([bufferRow, 0])
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
    scopes = @editSession.scopesForBufferPosition([precedingRow, Infinity])
    increaseIndentPattern = TextMateBundle.indentRegexForScope(scopes[0])
    return unless increaseIndentPattern

    currentIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    desiredIndentLevel = @editSession.indentationForBufferRow(precedingRow)
    desiredIndentLevel += 1 if increaseIndentPattern.test(precedingLine)
    if desiredIndentLevel > currentIndentLevel
      @editSession.setIndentationForBufferRow(bufferRow, desiredIndentLevel)

  autoDecreaseIndentForBufferRow: (bufferRow) ->
    scopes = @editSession.scopesForBufferPosition([bufferRow, 0])
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

  tokenizeLine: (line, stack, firstLine) ->
    {tokens, stack} = @grammar.tokenizeLine(line, stack, firstLine)
