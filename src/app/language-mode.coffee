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
          buffer.change(new Range([row, 0], [row, indentString.length]), indentString+commentStartString)

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

  # Given a buffer row, creates a fold at it.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns the new {Fold}.
  foldBufferRow: (bufferRow) ->
    for currentRow in [bufferRow..0]
      rowRange = @rowRangeForCommentAtBufferRow(currentRow)
      rowRange ?= @rowRangeForFoldAtBufferRow(currentRow)
      [startRow, endRow] = rowRange ? []
      continue unless startRow? and startRow <= bufferRow <= endRow
      fold = @editSession.displayBuffer.largestFoldStartingAtBufferRow(startRow)
      return @editSession.createFold(startRow, endRow) unless fold

  # Given a buffer row, this unfolds it.
  #
  # bufferRow - A {Number} indicating the buffer row
  unfoldBufferRow: (bufferRow) ->
    @editSession.displayBuffer.largestFoldContainingBufferRow(bufferRow)?.destroy()

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
        includeRowInFold = indentation == startIndentLevel and @foldEndRegexForScopes(scopes)?.search(@editSession.lineForBufferRow(row))
        foldEndRow = row if includeRowInFold
        break

      foldEndRow = row

    [bufferRow, foldEndRow]

  rowRangeForCommentAtBufferRow: (row) ->
    return unless @editSession.displayBuffer.tokenizedBuffer.lineForScreenRow(row).isComment()

    startRow = row
    for currentRow in [row-1..0]
      break if @buffer.isRowBlank(currentRow)
      break unless @editSession.displayBuffer.tokenizedBuffer.lineForScreenRow(currentRow).isComment()
      startRow = currentRow
    endRow = row
    for currentRow in [row+1..@buffer.getLastRow()]
      break if @buffer.isRowBlank(currentRow)
      break unless @editSession.displayBuffer.tokenizedBuffer.lineForScreenRow(currentRow).isComment()
      endRow = currentRow
    return [startRow, endRow] if startRow isnt endRow

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

  # Calculate a minimum indent level for a range of lines.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  #
  # Returns a {Number} of the indent level of the block of lines.
  minIndentLevelForRowRange: (startRow, endRow) ->
    buffer = @editSession.buffer
    indents = (@editSession.indentationForBufferRow(row) for row in [startRow..endRow] when buffer.lineForRow(row).trim())
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
