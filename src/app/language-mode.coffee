Range = require 'range'
_ = require 'underscore'
require 'underscore-extensions'
{OnigRegExp} = require 'oniguruma'
EventEmitter = require 'event-emitter'
Subscriber = require 'subscriber'

### Internal ###

module.exports =
class LanguageMode
  buffer: null
  grammar: null
  editSession: null
  currentGrammarScore: null

  ### Internal ###

  destroy: ->
    @unsubscribe()

  ### Public ###

  # Sets up a `LanguageMode` for the given {EditSession}.
  #
  # editSession - The {EditSession} to associate with
  constructor: (@editSession) ->
    @buffer = @editSession.buffer

  # Wraps the lines between two rows in comments.
  #
  # If the language doesn't have comment, nothing happens.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  #
  # Returns an {Array} of the commented {Ranges}.
  toggleLineCommentsForBufferRows: (start, end) ->
    scopes = @editSession.scopesForBufferPosition([start, 0])
    properties = syntax.propertiesForScope(scopes, "editor.commentStart")[0]
    return unless properties

    commentStartString = _.valueForKeyPath(properties, "editor.commentStart")
    commentEndString = _.valueForKeyPath(properties, "editor.commentEnd")

    return unless commentStartString

    buffer = @editSession.buffer
    commentStartRegexString = _.escapeRegExp(commentStartString).replace(/(\s+)$/, '($1)?')
    commentStartRegex = new OnigRegExp("^(\\s*)(#{commentStartRegexString})")
    shouldUncomment = commentStartRegex.test(buffer.lineForRow(start))

    if commentEndString
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
      if shouldUncomment and start isnt end
        shouldUncomment = [start+1..end].every (row) ->
          line = buffer.lineForRow(row)
          not line or commentStartRegex.test(line)
      if shouldUncomment
        for row in [start..end]
          if match = commentStartRegex.search(buffer.lineForRow(row))
            columnStart = match[1].length
            columnEnd = columnStart + match[2].length
            buffer.change([[row, columnStart], [row, columnEnd]], "")
      else
        indent = @minIndentLevelForRowRange(start, end)
        indentString = @editSession.buildIndentString(indent)
        for row in [start..end]
          buffer.change([[row, 0], [row, indentString.length]], indentString + commentStartString)

  # Folds all the foldable lines in the buffer.
  foldAll: ->
    for currentRow in [0..@buffer.getLastRow()]
      [startRow, endRow] = @rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow?
      @editSession.createFold(startRow, endRow)

  # Unfolds all the foldable lines in the buffer.
  unfoldAll: ->
    for row in [@buffer.getLastRow()..0]
      fold.destroy() for fold in @editSession.displayBuffer.foldsStartingAtBufferRow(row)

  # Fold all comment and code blocks at a given indentLevel
  #
  # indentLevel - A {Number} indicating indentLevel; 0 based.
  foldAllAtIndentLevel: (indentLevel) ->
    for currentRow in [0..@buffer.getLastRow()]
      [startRow, endRow] = @rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow?

      # assumption: startRow will always be the min indent level for the entire range
      if @editSession.indentationForBufferRow(startRow) == indentLevel
        @editSession.createFold(startRow, endRow)

  # Given a buffer row, creates a fold at it.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns the new {Fold}.
  foldBufferRow: (bufferRow) ->
    for currentRow in [bufferRow..0]
      [startRow, endRow] = @rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow? and startRow <= bufferRow <= endRow
      fold = @editSession.displayBuffer.largestFoldStartingAtBufferRow(startRow)
      return @editSession.createFold(startRow, endRow) unless fold

  # Given a buffer row, this unfolds it.
  #
  # bufferRow - A {Number} indicating the buffer row
  unfoldBufferRow: (bufferRow) ->
    @editSession.displayBuffer.largestFoldContainingBufferRow(bufferRow)?.destroy()

  # Find the row range for a fold at a given bufferRow. Will handle comments
  # and code.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns an {Array} of the [startRow, endRow]. Returns null if no range.
  rowRangeForFoldAtBufferRow: (bufferRow) ->
    rowRange = @rowRangeForCommentFoldAtBufferRow(bufferRow)
    rowRange ?= @rowRangeForCodeFoldAtBufferRow(bufferRow)
    rowRange

  rowRangeForCommentFoldAtBufferRow: (bufferRow) ->
    return unless @editSession.displayBuffer.tokenizedBuffer.lineForScreenRow(bufferRow).isComment()

    startRow = bufferRow
    for currentRow in [bufferRow-1..0]
      break if @buffer.isRowBlank(currentRow)
      break unless @editSession.displayBuffer.tokenizedBuffer.lineForScreenRow(currentRow).isComment()
      startRow = currentRow
    endRow = bufferRow
    for currentRow in [bufferRow+1..@buffer.getLastRow()]
      break if @buffer.isRowBlank(currentRow)
      break unless @editSession.displayBuffer.tokenizedBuffer.lineForScreenRow(currentRow).isComment()
      endRow = currentRow
    return [startRow, endRow] if startRow isnt endRow

  rowRangeForCodeFoldAtBufferRow: (bufferRow) ->
    return null unless @doesBufferRowStartFold(bufferRow)

    startIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    scopes = @editSession.scopesForBufferPosition([bufferRow, 0])
    for row in [(bufferRow + 1)..@editSession.getLastBufferRow()]
      continue if @editSession.isBufferRowBlank(row)
      indentation = @editSession.indentationForBufferRow(row)
      if indentation <= startIndentLevel
        includeRowInFold = indentation == startIndentLevel and @foldEndRegexForScopes(scopes)?.search(@editSession.lineForBufferRow(row))
        foldEndRow = row if includeRowInFold
        break

      foldEndRow = row

    [bufferRow, foldEndRow]

  doesBufferRowStartFold: (bufferRow) ->
    return false if @editSession.isBufferRowBlank(bufferRow)
    nextNonEmptyRow = @editSession.nextNonBlankBufferRow(bufferRow)
    return false unless nextNonEmptyRow?
    @editSession.indentationForBufferRow(nextNonEmptyRow) > @editSession.indentationForBufferRow(bufferRow)

  # Find a row range for a 'paragraph' around specified bufferRow.
  # Right now, a paragraph is a block of text bounded by and empty line or a
  # block of text that is not the same type (comments next to source code).
  rowRangeForParagraphAtBufferRow: (bufferRow) ->
    return unless /\w/.test(@editSession.lineForBufferRow(bufferRow))

    isRowComment = (row) =>
      @editSession.displayBuffer.tokenizedBuffer.lineForScreenRow(row).isComment()

    if isRowComment(bufferRow)
      isOriginalRowComment = true
      range = @rowRangeForCommentAtBufferRow(bufferRow)
      [firstRow, lastRow] = range or [bufferRow, bufferRow]
    else
      isOriginalRowComment = false
      [firstRow, lastRow] = [0, @editSession.getLastBufferRow()-1]

    startRow = bufferRow
    while startRow > firstRow
      break if isRowComment(startRow - 1) != isOriginalRowComment
      break unless /\w/.test(@editSession.lineForBufferRow(startRow - 1))
      startRow--

    endRow = bufferRow
    lastRow = @editSession.getLastBufferRow()
    while endRow < lastRow
      break if isRowComment(endRow + 1) != isOriginalRowComment
      break unless /\w/.test(@editSession.lineForBufferRow(endRow + 1))
      endRow++

    new Range([startRow, 0], [endRow, @editSession.lineLengthForBufferRow(endRow)])

  # Given a buffer row, this returns a suggested indentation level.
  #
  # The indentation level provided is based on the current {LanguageMode}.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns a {Number}.
  suggestedIndentForBufferRow: (bufferRow) ->
    currentIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    scopes = @editSession.scopesForBufferPosition([bufferRow, 0])
    return currentIndentLevel unless increaseIndentRegex = @increaseIndentRegexForScopes(scopes)

    currentLine = @buffer.lineForRow(bufferRow)
    precedingRow = @buffer.previousNonBlankRow(bufferRow)
    return currentIndentLevel unless precedingRow?

    precedingLine = @buffer.lineForRow(precedingRow)
    desiredIndentLevel = @editSession.indentationForBufferRow(precedingRow)
    desiredIndentLevel += 1 if increaseIndentRegex.test(precedingLine) and not @editSession.isBufferRowCommented(precedingRow)

    return desiredIndentLevel unless decreaseIndentRegex = @decreaseIndentRegexForScopes(scopes)
    desiredIndentLevel -= 1 if decreaseIndentRegex.test(currentLine)

    desiredIndentLevel

  # Calculate a minimum indent level for a range of lines excluding empty lines.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  #
  # Returns a {Number} of the indent level of the block of lines.
  minIndentLevelForRowRange: (startRow, endRow) ->
    indents = (@editSession.indentationForBufferRow(row) for row in [startRow..endRow] when not @editSession.isBufferRowBlank(row))
    indents = [0] unless indents.length
    Math.min(indents...)

  # Indents all the rows between two buffer row numbers.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  autoIndentBufferRows: (startRow, endRow) ->
    @autoIndentBufferRow(row) for row in [startRow..endRow]

  # Given a buffer row, this indents it.
  #
  # bufferRow - The row {Number}
  autoIndentBufferRow: (bufferRow) ->
    indentLevel = @suggestedIndentForBufferRow(bufferRow)
    @editSession.setIndentationForBufferRow(bufferRow, indentLevel)

  # Given a buffer row, this decreases the indentation.
  #
  # bufferRow - The row {Number}
  autoDecreaseIndentForBufferRow: (bufferRow) ->
    scopes = @editSession.scopesForBufferPosition([bufferRow, 0])
    increaseIndentRegex = @increaseIndentRegexForScopes(scopes)
    decreaseIndentRegex = @decreaseIndentRegexForScopes(scopes)
    return unless increaseIndentRegex and decreaseIndentRegex

    line = @buffer.lineForRow(bufferRow)
    return unless decreaseIndentRegex.test(line)

    currentIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    return if currentIndentLevel is 0
    precedingRow = @buffer.previousNonBlankRow(bufferRow)
    return unless precedingRow?
    precedingLine = @buffer.lineForRow(precedingRow)

    desiredIndentLevel = @editSession.indentationForBufferRow(precedingRow)
    desiredIndentLevel -= 1 unless increaseIndentRegex.test(precedingLine)
    if desiredIndentLevel >= 0 and desiredIndentLevel < currentIndentLevel
      @editSession.setIndentationForBufferRow(bufferRow, desiredIndentLevel)

  tokenizeLine: (line, stack, firstLine) ->
    {tokens, stack} = @grammar.tokenizeLine(line, stack, firstLine)

  increaseIndentRegexForScopes: (scopes) ->
    if increaseIndentPattern = syntax.getProperty(scopes, 'editor.increaseIndentPattern')
      new OnigRegExp(increaseIndentPattern)

  decreaseIndentRegexForScopes: (scopes) ->
    if decreaseIndentPattern = syntax.getProperty(scopes, 'editor.decreaseIndentPattern')
      new OnigRegExp(decreaseIndentPattern)

  foldEndRegexForScopes: (scopes) ->
    if foldEndPattern = syntax.getProperty(scopes, 'editor.foldEndPattern')
      new OnigRegExp(foldEndPattern)

_.extend LanguageMode.prototype, EventEmitter
_.extend LanguageMode.prototype, Subscriber
