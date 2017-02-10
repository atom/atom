{Range} = require 'text-buffer'
_ = require 'underscore-plus'
{OnigRegExp} = require 'oniguruma'
ScopeDescriptor = require './scope-descriptor'
NullGrammar = require './null-grammar'

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

  # Folds all the foldable lines in the buffer.
  foldAll: ->
    @unfoldAll()
    foldedRowRanges = {}
    for currentRow in [0..@buffer.getLastRow()] by 1
      rowRange = [startRow, endRow] = @rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow?
      continue if foldedRowRanges[rowRange]

      @editor.foldBufferRowRange(startRow, endRow)
      foldedRowRanges[rowRange] = true
    return

  # Unfolds all the foldable lines in the buffer.
  unfoldAll: ->
    @editor.displayLayer.destroyAllFolds()

  # Fold all comment and code blocks at a given indentLevel
  #
  # indentLevel - A {Number} indicating indentLevel; 0 based.
  foldAllAtIndentLevel: (indentLevel) ->
    @unfoldAll()
    foldedRowRanges = {}
    for currentRow in [0..@buffer.getLastRow()] by 1
      rowRange = [startRow, endRow] = @rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow?
      continue if foldedRowRanges[rowRange]

      # assumption: startRow will always be the min indent level for the entire range
      if @editor.indentationForBufferRow(startRow) is indentLevel
        @editor.foldBufferRowRange(startRow, endRow)
        foldedRowRanges[rowRange] = true
    return

  # Given a buffer row, creates a fold at it.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns the new {Fold}.
  foldBufferRow: (bufferRow) ->
    for currentRow in [bufferRow..0] by -1
      [startRow, endRow] = @rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow? and startRow <= bufferRow <= endRow
      unless @editor.isFoldedAtBufferRow(startRow)
        return @editor.foldBufferRowRange(startRow, endRow)

  # Find the row range for a fold at a given bufferRow. Will handle comments
  # and code.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns an {Array} of the [startRow, endRow]. Returns null if no range.
  rowRangeForFoldAtBufferRow: (bufferRow) ->
    rowRange = @rowRangeForCommentAtBufferRow(bufferRow)
    rowRange ?= @rowRangeForCodeFoldAtBufferRow(bufferRow)
    rowRange

  rowRangeForCommentAtBufferRow: (bufferRow) ->
    return unless @editor.tokenizedBuffer.tokenizedLines[bufferRow]?.isComment()

    startRow = bufferRow
    endRow = bufferRow

    if bufferRow > 0
      for currentRow in [bufferRow-1..0] by -1
        break unless @editor.tokenizedBuffer.tokenizedLines[currentRow]?.isComment()
        startRow = currentRow

    if bufferRow < @buffer.getLastRow()
      for currentRow in [bufferRow+1..@buffer.getLastRow()] by 1
        break unless @editor.tokenizedBuffer.tokenizedLines[currentRow]?.isComment()
        endRow = currentRow

    return [startRow, endRow] if startRow isnt endRow

  rowRangeForCodeFoldAtBufferRow: (bufferRow) ->
    return null unless @isFoldableAtBufferRow(bufferRow)

    startIndentLevel = @editor.indentationForBufferRow(bufferRow)
    scopeDescriptor = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])
    for row in [(bufferRow + 1)..@editor.getLastBufferRow()] by 1
      continue if @editor.isBufferRowBlank(row)
      indentation = @editor.indentationForBufferRow(row)
      if indentation <= startIndentLevel
        includeRowInFold = indentation is startIndentLevel and @foldEndRegexForScopeDescriptor(scopeDescriptor)?.searchSync(@editor.lineTextForBufferRow(row))
        foldEndRow = row if includeRowInFold
        break

      foldEndRow = row

    [bufferRow, foldEndRow]

  isFoldableAtBufferRow: (bufferRow) ->
    @editor.tokenizedBuffer.isFoldableAtRow(bufferRow)

  # Returns a {Boolean} indicating whether the line at the given buffer
  # row is a comment.
  isLineCommentedAtBufferRow: (bufferRow) ->
    return false unless 0 <= bufferRow <= @editor.getLastBufferRow()
    @editor.tokenizedBuffer.tokenizedLines[bufferRow]?.isComment()

  # Find a row range for a 'paragraph' around specified bufferRow. A paragraph
  # is a block of text bounded by and empty line or a block of text that is not
  # the same type (comments next to source code).
  rowRangeForParagraphAtBufferRow: (bufferRow) ->
    scope = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])
    commentStrings = @editor.getCommentStrings(scope)
    commentStartRegex = null
    if commentStrings?.commentStartString? and not commentStrings.commentEndString?
      commentStartRegexString = _.escapeRegExp(commentStrings.commentStartString).replace(/(\s+)$/, '(?:$1)?')
      commentStartRegex = new OnigRegExp("^(\\s*)(#{commentStartRegexString})")

    filterCommentStart = (line) ->
      if commentStartRegex?
        matches = commentStartRegex.searchSync(line)
        line = line.substring(matches[0].end) if matches?.length
      line

    return unless /\S/.test(filterCommentStart(@editor.lineTextForBufferRow(bufferRow)))

    if @isLineCommentedAtBufferRow(bufferRow)
      isOriginalRowComment = true
      range = @rowRangeForCommentAtBufferRow(bufferRow)
      [firstRow, lastRow] = range or [bufferRow, bufferRow]
    else
      isOriginalRowComment = false
      [firstRow, lastRow] = [0, @editor.getLastBufferRow()-1]

    startRow = bufferRow
    while startRow > firstRow
      break if @isLineCommentedAtBufferRow(startRow - 1) isnt isOriginalRowComment
      break unless /\S/.test(filterCommentStart(@editor.lineTextForBufferRow(startRow - 1)))
      startRow--

    endRow = bufferRow
    lastRow = @editor.getLastBufferRow()
    while endRow < lastRow
      break if @isLineCommentedAtBufferRow(endRow + 1) isnt isOriginalRowComment
      break unless /\S/.test(filterCommentStart(@editor.lineTextForBufferRow(endRow + 1)))
      endRow++

    new Range([startRow, 0], [endRow, @editor.lineTextForBufferRow(endRow).length])

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

  foldEndRegexForScopeDescriptor: (scopeDescriptor) ->
    @cacheRegex(@editor.getFoldEndPattern(scopeDescriptor))
