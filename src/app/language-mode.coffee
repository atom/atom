Range = require 'range'
_ = require 'underscore'
require 'underscore-extensions'
{OnigRegExp} = require 'oniguruma'

module.exports =
class LanguageMode
  buffer = null
  grammar = null
  editSession = null

  constructor: (@editSession) ->
    @buffer = @editSession.buffer
    @reloadGrammar()

  reloadGrammar: ->
    path = @buffer.getPath()
    pathContents = @buffer.cachedDiskContents
    previousGrammar = @grammar
    @grammar = syntax.selectGrammar(path, pathContents)
    throw new Error("No grammar found for path: #{path}") unless @grammar
    previousGrammar isnt @grammar

  # Public: Wraps the lines between two rows in comments.
  #
  # If the language doesn't have comment, nothing happens.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  toggleLineCommentsForBufferRows: (start, end) ->
    scopes = @editSession.scopesForBufferPosition([start, 0])
    return unless commentStartString = syntax.getProperty(scopes, "editor.commentStart")

    buffer = @editSession.buffer
    commentStartRegexString = _.escapeRegExp(commentStartString).replace(/(\s+)$/, '($1)?')
    commentStartRegex = new OnigRegExp("^(\\s*)(#{commentStartRegexString})")
    shouldUncomment = commentStartRegex.test(buffer.lineForRow(start))

    if commentEndString = syntax.getProperty(scopes, "editor.commentEnd")
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
        includeRowInFold = indentation == startIndentLevel and @foldEndRegexForScopes(scopes)?.search(@editSession.lineForBufferRow(row))
        foldEndRow = row if includeRowInFold
        break

      foldEndRow = row

    [bufferRow, foldEndRow]

  # Public: Given a buffer row, this returns a suggested indentation level.
  #
  # The indentation level provided is based on the current {LangugaeMode}. 
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
    desiredIndentLevel += 1 if increaseIndentRegex.test(precedingLine)

    return desiredIndentLevel unless decreaseIndentRegex = @decreaseIndentRegexForScopes(scopes)
    desiredIndentLevel -= 1 if decreaseIndentRegex.test(currentLine)

    Math.max(desiredIndentLevel, currentIndentLevel)

  # Public: Indents all the rows between two buffer row numbers.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  autoIndentBufferRows: (startRow, endRow) ->
    @autoIndentBufferRow(row) for row in [startRow..endRow]

  # Public: Given a buffer row, this indents it.
  #
  # bufferRow - The row {Number}
  autoIndentBufferRow: (bufferRow) ->
    @autoIncreaseIndentForBufferRow(bufferRow)
    @autoDecreaseIndentForBufferRow(bufferRow)

  # Public: Given a buffer row, this increases the indentation.
  #
  # bufferRow - The row {Number}
  autoIncreaseIndentForBufferRow: (bufferRow) ->
    precedingRow = @buffer.previousNonBlankRow(bufferRow)
    return unless precedingRow?

    precedingLine = @editSession.lineForBufferRow(precedingRow)
    scopes = @editSession.scopesForBufferPosition([precedingRow, Infinity])
    increaseIndentRegex = @increaseIndentRegexForScopes(scopes)
    return unless increaseIndentRegex

    currentIndentLevel = @editSession.indentationForBufferRow(bufferRow)
    desiredIndentLevel = @editSession.indentationForBufferRow(precedingRow)
    desiredIndentLevel += 1 if increaseIndentRegex.test(precedingLine)
    if desiredIndentLevel > currentIndentLevel
      @editSession.setIndentationForBufferRow(bufferRow, desiredIndentLevel)

  # Public: Given a buffer row, this decreases the indentation.
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
