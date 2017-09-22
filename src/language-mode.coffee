{Range, Point} = require 'text-buffer'
_ = require 'underscore-plus'
{OnigRegExp} = require 'oniguruma'
ScopeDescriptor = require './scope-descriptor'
NullGrammar = require './null-grammar'

NON_WHITESPACE_REGEX = /\S/

module.exports =
class LanguageMode
  # Sets up a `LanguageMode` for the given {TextEditor}.
  #
  # editor - The {TextEditor} to associate with
  constructor: (@editor) ->
    {@buffer} = @editor
    @regexesByPattern = {}

  destroy: ->

  toggleLineCommentForBufferRow: (row) ->
    @toggleLineCommentsForBufferRows(row, row)

  # Wraps the lines between two rows in comments.
  #
  # If the language doesn't have comment, nothing happens.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  toggleLineCommentsForBufferRows: (start, end) ->
    scope = @editor.scopeDescriptorForBufferPosition([start, 0])
    commentStrings = @editor.getCommentStrings(scope)
    return unless commentStrings?.commentStartString
    {commentStartString, commentEndString} = commentStrings

    buffer = @editor.buffer
    commentStartRegexString = _.escapeRegExp(commentStartString).replace(/(\s+)$/, '(?:$1)?')
    commentStartRegex = new OnigRegExp("^(\\s*)(#{commentStartRegexString})")

    if commentEndString
      shouldUncomment = commentStartRegex.testSync(buffer.lineForRow(start))
      if shouldUncomment
        commentEndRegexString = _.escapeRegExp(commentEndString).replace(/^(\s+)/, '(?:$1)?')
        commentEndRegex = new OnigRegExp("(#{commentEndRegexString})(\\s*)$")
        startMatch =  commentStartRegex.searchSync(buffer.lineForRow(start))
        endMatch = commentEndRegex.searchSync(buffer.lineForRow(end))
        if startMatch and endMatch
          buffer.transact ->
            columnStart = startMatch[1].length
            columnEnd = columnStart + startMatch[2].length
            buffer.setTextInRange([[start, columnStart], [start, columnEnd]], "")

            endLength = buffer.lineLengthForRow(end) - endMatch[2].length
            endColumn = endLength - endMatch[1].length
            buffer.setTextInRange([[end, endColumn], [end, endLength]], "")
      else
        buffer.transact ->
          indentLength = buffer.lineForRow(start).match(/^\s*/)?[0].length ? 0
          buffer.insert([start, indentLength], commentStartString)
          buffer.insert([end, buffer.lineLengthForRow(end)], commentEndString)
    else
      allBlank = true
      allBlankOrCommented = true

      for row in [start..end] by 1
        line = buffer.lineForRow(row)
        blank = line?.match(/^\s*$/)

        allBlank = false unless blank
        allBlankOrCommented = false unless blank or commentStartRegex.testSync(line)

      shouldUncomment = allBlankOrCommented and not allBlank

      if shouldUncomment
        for row in [start..end] by 1
          if match = commentStartRegex.searchSync(buffer.lineForRow(row))
            columnStart = match[1].length
            columnEnd = columnStart + match[2].length
            buffer.setTextInRange([[row, columnStart], [row, columnEnd]], "")
      else
        if start is end
          indent = @editor.indentationForBufferRow(start)
        else
          indent = @minIndentLevelForRowRange(start, end)
        indentString = @editor.buildIndentString(indent)
        tabLength = @editor.getTabLength()
        indentRegex = new RegExp("(\t|[ ]{#{tabLength}}){#{Math.floor(indent)}}")
        for row in [start..end] by 1
          line = buffer.lineForRow(row)
          if indentLength = line.match(indentRegex)?[0].length
            buffer.insert([row, indentLength], commentStartString)
          else
            buffer.setTextInRange([[row, 0], [row, indentString.length]], indentString + commentStartString)
    return

  # Find a row range for a 'paragraph' around specified bufferRow. A paragraph
  # is a block of text bounded by and empty line or a block of text that is not
  # the same type (comments next to source code).
  rowRangeForParagraphAtBufferRow: (bufferRow) ->
    return unless NON_WHITESPACE_REGEX.test(@editor.lineTextForBufferRow(bufferRow))

    isCommented = @editor.tokenizedBuffer.isRowCommented(bufferRow)

    startRow = bufferRow
    while startRow > 0
      break unless NON_WHITESPACE_REGEX.test(@editor.lineTextForBufferRow(startRow - 1))
      break if @editor.tokenizedBuffer.isRowCommented(startRow - 1) isnt isCommented
      startRow--

    endRow = bufferRow
    rowCount = @editor.getLineCount()
    while endRow < rowCount
      break unless NON_WHITESPACE_REGEX.test(@editor.lineTextForBufferRow(endRow + 1))
      break if @editor.tokenizedBuffer.isRowCommented(endRow + 1) isnt isCommented
      endRow++

    new Range(new Point(startRow, 0), new Point(endRow, @editor.buffer.lineLengthForRow(endRow)))

  # Given a buffer row, this returns a suggested indentation level.
  #
  # The indentation level provided is based on the current {LanguageMode}.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns a {Number}.
  suggestedIndentForBufferRow: (bufferRow, options) ->
    line = @buffer.lineForRow(bufferRow)
    tokenizedLine = @editor.tokenizedBuffer.tokenizedLineForRow(bufferRow)
    @suggestedIndentForTokenizedLineAtBufferRow(bufferRow, line, tokenizedLine, options)

  suggestedIndentForLineAtBufferRow: (bufferRow, line, options) ->
    tokenizedLine = @editor.tokenizedBuffer.buildTokenizedLineForRowWithText(bufferRow, line)
    @suggestedIndentForTokenizedLineAtBufferRow(bufferRow, line, tokenizedLine, options)

  suggestedIndentForTokenizedLineAtBufferRow: (bufferRow, line, tokenizedLine, options) ->
    iterator = tokenizedLine.getTokenIterator()
    iterator.next()
    scopeDescriptor = new ScopeDescriptor(scopes: iterator.getScopes())

    increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)
    decreaseIndentRegex = @decreaseIndentRegexForScopeDescriptor(scopeDescriptor)
    decreaseNextIndentRegex = @decreaseNextIndentRegexForScopeDescriptor(scopeDescriptor)

    if options?.skipBlankLines ? true
      precedingRow = @buffer.previousNonBlankRow(bufferRow)
      return 0 unless precedingRow?
    else
      precedingRow = bufferRow - 1
      return 0 if precedingRow < 0

    desiredIndentLevel = @editor.indentationForBufferRow(precedingRow)
    return desiredIndentLevel unless increaseIndentRegex

    unless @editor.isBufferRowCommented(precedingRow)
      precedingLine = @buffer.lineForRow(precedingRow)
      desiredIndentLevel += 1 if increaseIndentRegex?.testSync(precedingLine)
      desiredIndentLevel -= 1 if decreaseNextIndentRegex?.testSync(precedingLine)

    unless @buffer.isRowBlank(precedingRow)
      desiredIndentLevel -= 1 if decreaseIndentRegex?.testSync(line)

    Math.max(desiredIndentLevel, 0)

  # Calculate a minimum indent level for a range of lines excluding empty lines.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  #
  # Returns a {Number} of the indent level of the block of lines.
  minIndentLevelForRowRange: (startRow, endRow) ->
    indents = (@editor.indentationForBufferRow(row) for row in [startRow..endRow] by 1 when not @editor.isBufferRowBlank(row))
    indents = [0] unless indents.length
    Math.min(indents...)

  # Indents all the rows between two buffer row numbers.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  autoIndentBufferRows: (startRow, endRow) ->
    @autoIndentBufferRow(row) for row in [startRow..endRow] by 1
    return

  # Given a buffer row, this indents it.
  #
  # bufferRow - The row {Number}.
  # options - An options {Object} to pass through to {TextEditor::setIndentationForBufferRow}.
  autoIndentBufferRow: (bufferRow, options) ->
    indentLevel = @suggestedIndentForBufferRow(bufferRow, options)
    @editor.setIndentationForBufferRow(bufferRow, indentLevel, options)

  # Given a buffer row, this decreases the indentation.
  #
  # bufferRow - The row {Number}
  autoDecreaseIndentForBufferRow: (bufferRow) ->
    scopeDescriptor = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])
    return unless decreaseIndentRegex = @decreaseIndentRegexForScopeDescriptor(scopeDescriptor)

    line = @buffer.lineForRow(bufferRow)
    return unless decreaseIndentRegex.testSync(line)

    currentIndentLevel = @editor.indentationForBufferRow(bufferRow)
    return if currentIndentLevel is 0

    precedingRow = @buffer.previousNonBlankRow(bufferRow)
    return unless precedingRow?

    precedingLine = @buffer.lineForRow(precedingRow)
    desiredIndentLevel = @editor.indentationForBufferRow(precedingRow)

    if increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)
      desiredIndentLevel -= 1 unless increaseIndentRegex.testSync(precedingLine)

    if decreaseNextIndentRegex = @decreaseNextIndentRegexForScopeDescriptor(scopeDescriptor)
      desiredIndentLevel -= 1 if decreaseNextIndentRegex.testSync(precedingLine)

    if desiredIndentLevel >= 0 and desiredIndentLevel < currentIndentLevel
      @editor.setIndentationForBufferRow(bufferRow, desiredIndentLevel)

  cacheRegex: (pattern) ->
    if pattern
      @regexesByPattern[pattern] ?= new OnigRegExp(pattern)

  increaseIndentRegexForScopeDescriptor: (scopeDescriptor) ->
    @cacheRegex(@editor.getIncreaseIndentPattern(scopeDescriptor))

  decreaseIndentRegexForScopeDescriptor: (scopeDescriptor) ->
    @cacheRegex(@editor.getDecreaseIndentPattern(scopeDescriptor))

  decreaseNextIndentRegexForScopeDescriptor: (scopeDescriptor) ->
    @cacheRegex(@editor.getDecreaseNextIndentPattern(scopeDescriptor))
