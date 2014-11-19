{Range} = require 'text-buffer'
_ = require 'underscore-plus'
{OnigRegExp} = require 'oniguruma'
{Emitter, Subscriber} = require 'emissary'

module.exports =
class LanguageMode
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  # Sets up a `LanguageMode` for the given {TextEditor}.
  #
  # editor - The {TextEditor} to associate with
  constructor: (@editor) ->
    {@buffer} = @editor

  destroy: ->
    @unsubscribe()

  toggleLineCommentForBufferRow: (row) ->
    @toggleLineCommentsForBufferRows(row, row)

  # Wraps the lines between two rows in comments.
  #
  # If the language doesn't have comment, nothing happens.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  #
  # Returns an {Array} of the commented {Ranges}.
  toggleLineCommentsForBufferRows: (start, end) ->
    scopeDescriptor = @editor.scopeDescriptorForBufferPosition([start, 0])
    properties = atom.config.settingsForScopeDescriptor(scopeDescriptor, 'editor.commentStart')[0]
    return unless properties

    commentStartString = _.valueForKeyPath(properties, 'editor.commentStart')
    commentEndString = _.valueForKeyPath(properties, 'editor.commentEnd')

    return unless commentStartString

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

      for row in [start..end]
        line = buffer.lineForRow(row)
        blank = line?.match(/^\s*$/)

        allBlank = false unless blank
        allBlankOrCommented = false unless blank or commentStartRegex.testSync(line)

      shouldUncomment = allBlankOrCommented and not allBlank

      if shouldUncomment
        for row in [start..end]
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
        for row in [start..end]
          line = buffer.lineForRow(row)
          if indentLength = line.match(indentRegex)?[0].length
            buffer.insert([row, indentLength], commentStartString)
          else
            buffer.setTextInRange([[row, 0], [row, indentString.length]], indentString + commentStartString)

  # Folds all the foldable lines in the buffer.
  foldAll: ->
    for currentRow in [0..@buffer.getLastRow()]
      [startRow, endRow] = @rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow?
      @editor.createFold(startRow, endRow)

  # Unfolds all the foldable lines in the buffer.
  unfoldAll: ->
    for row in [@buffer.getLastRow()..0]
      fold.destroy() for fold in @editor.displayBuffer.foldsStartingAtBufferRow(row)

  # Fold all comment and code blocks at a given indentLevel
  #
  # indentLevel - A {Number} indicating indentLevel; 0 based.
  foldAllAtIndentLevel: (indentLevel) ->
    for currentRow in [0..@buffer.getLastRow()]
      [startRow, endRow] = @rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow?

      # assumption: startRow will always be the min indent level for the entire range
      if @editor.indentationForBufferRow(startRow) == indentLevel
        @editor.createFold(startRow, endRow)

  # Given a buffer row, creates a fold at it.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns the new {Fold}.
  foldBufferRow: (bufferRow) ->
    for currentRow in [bufferRow..0]
      [startRow, endRow] = @rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow? and startRow <= bufferRow <= endRow
      fold = @editor.displayBuffer.largestFoldStartingAtBufferRow(startRow)
      return @editor.createFold(startRow, endRow) unless fold

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
    return unless @editor.displayBuffer.tokenizedBuffer.tokenizedLineForRow(bufferRow).isComment()

    startRow = bufferRow
    endRow = bufferRow

    if bufferRow > 0
      for currentRow in [bufferRow-1..0]
        break if @buffer.isRowBlank(currentRow)
        break unless @editor.displayBuffer.tokenizedBuffer.tokenizedLineForRow(currentRow).isComment()
        startRow = currentRow

    if bufferRow < @buffer.getLastRow()
      for currentRow in [bufferRow+1..@buffer.getLastRow()]
        break if @buffer.isRowBlank(currentRow)
        break unless @editor.displayBuffer.tokenizedBuffer.tokenizedLineForRow(currentRow).isComment()
        endRow = currentRow

    return [startRow, endRow] if startRow isnt endRow

  rowRangeForCodeFoldAtBufferRow: (bufferRow) ->
    return null unless @isFoldableAtBufferRow(bufferRow)

    startIndentLevel = @editor.indentationForBufferRow(bufferRow)
    scopeDescriptor = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])
    for row in [(bufferRow + 1)..@editor.getLastBufferRow()]
      continue if @editor.isBufferRowBlank(row)
      indentation = @editor.indentationForBufferRow(row)
      if indentation <= startIndentLevel
        includeRowInFold = indentation == startIndentLevel and @foldEndRegexForScopeDescriptor(scopeDescriptor)?.searchSync(@editor.lineTextForBufferRow(row))
        foldEndRow = row if includeRowInFold
        break

      foldEndRow = row

    [bufferRow, foldEndRow]

  # Public: Returns a {Boolean} indicating whether the given buffer row starts a
  # foldable row range. Rows that are "foldable" have a fold icon next to their
  # icon in the gutter in the default configuration.
  isFoldableAtBufferRow: (bufferRow) ->
    @isFoldableCodeAtBufferRow(bufferRow) or @isFoldableCommentAtBufferRow(bufferRow)

  # Returns a {Boolean} indicating whether the given buffer row starts
  # a a foldable row range due to the code's indentation patterns.
  isFoldableCodeAtBufferRow: (bufferRow) ->
    return false if @editor.isBufferRowBlank(bufferRow) or @isLineCommentedAtBufferRow(bufferRow)
    nextNonEmptyRow = @editor.nextNonBlankBufferRow(bufferRow)
    return false unless nextNonEmptyRow?
    @editor.indentationForBufferRow(nextNonEmptyRow) > @editor.indentationForBufferRow(bufferRow)

  # Returns a {Boolean} indicating whether the given buffer row starts
  # a foldable row range due to being the start of a multi-line comment.
  isFoldableCommentAtBufferRow: (bufferRow) ->
    @isLineCommentedAtBufferRow(bufferRow) and
      @isLineCommentedAtBufferRow(bufferRow + 1) and
        not @isLineCommentedAtBufferRow(bufferRow - 1)

  # Returns a {Boolean} indicating whether the line at the given buffer
  # row is a comment.
  isLineCommentedAtBufferRow: (bufferRow) ->
    return false unless 0 <= bufferRow <= @editor.getLastBufferRow()
    @editor.displayBuffer.tokenizedBuffer.tokenizedLineForRow(bufferRow).isComment()

  # Find a row range for a 'paragraph' around specified bufferRow.
  # Right now, a paragraph is a block of text bounded by and empty line or a
  # block of text that is not the same type (comments next to source code).
  rowRangeForParagraphAtBufferRow: (bufferRow) ->
    return unless /\w/.test(@editor.lineTextForBufferRow(bufferRow))

    if @isLineCommentedAtBufferRow(bufferRow)
      isOriginalRowComment = true
      range = @rowRangeForCommentAtBufferRow(bufferRow)
      [firstRow, lastRow] = range or [bufferRow, bufferRow]
    else
      isOriginalRowComment = false
      [firstRow, lastRow] = [0, @editor.getLastBufferRow()-1]

    startRow = bufferRow
    while startRow > firstRow
      break if @isLineCommentedAtBufferRow(startRow - 1) != isOriginalRowComment
      break unless /\w/.test(@editor.lineTextForBufferRow(startRow - 1))
      startRow--

    endRow = bufferRow
    lastRow = @editor.getLastBufferRow()
    while endRow < lastRow
      break if @isLineCommentedAtBufferRow(endRow + 1) != isOriginalRowComment
      break unless /\w/.test(@editor.lineTextForBufferRow(endRow + 1))
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
    currentIndentLevel = @editor.indentationForBufferRow(bufferRow)
    scopeDescriptor = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])
    return currentIndentLevel unless increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)

    currentLine = @buffer.lineForRow(bufferRow)
    if options?.skipBlankLines ? true
      precedingRow = @buffer.previousNonBlankRow(bufferRow)
      return 0 unless precedingRow?
    else
      precedingRow = bufferRow - 1
      return currentIndentLevel if precedingRow < 0

    precedingLine = @buffer.lineForRow(precedingRow)
    desiredIndentLevel = @editor.indentationForBufferRow(precedingRow)
    desiredIndentLevel += 1 if increaseIndentRegex.testSync(precedingLine) and not @editor.isBufferRowCommented(precedingRow)

    return desiredIndentLevel unless decreaseIndentRegex = @decreaseIndentRegexForScopeDescriptor(scopeDescriptor)
    desiredIndentLevel -= 1 if decreaseIndentRegex.testSync(currentLine)

    Math.max(desiredIndentLevel, 0)

  # Calculate a minimum indent level for a range of lines excluding empty lines.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  #
  # Returns a {Number} of the indent level of the block of lines.
  minIndentLevelForRowRange: (startRow, endRow) ->
    indents = (@editor.indentationForBufferRow(row) for row in [startRow..endRow] when not @editor.isBufferRowBlank(row))
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
    increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)
    decreaseIndentRegex = @decreaseIndentRegexForScopeDescriptor(scopeDescriptor)
    return unless increaseIndentRegex and decreaseIndentRegex

    line = @buffer.lineForRow(bufferRow)
    return unless decreaseIndentRegex.testSync(line)

    currentIndentLevel = @editor.indentationForBufferRow(bufferRow)
    return if currentIndentLevel is 0
    precedingRow = @buffer.previousNonBlankRow(bufferRow)
    return unless precedingRow?
    precedingLine = @buffer.lineForRow(precedingRow)

    desiredIndentLevel = @editor.indentationForBufferRow(precedingRow)
    desiredIndentLevel -= 1 unless increaseIndentRegex.testSync(precedingLine)
    if desiredIndentLevel >= 0 and desiredIndentLevel < currentIndentLevel
      @editor.setIndentationForBufferRow(bufferRow, desiredIndentLevel)

  getRegexForProperty: (scopeDescriptor, property) ->
    if pattern = atom.config.get(scopeDescriptor, property)
      new OnigRegExp(pattern)

  increaseIndentRegexForScopeDescriptor: (scopeDescriptor) ->
    @getRegexForProperty(scopeDescriptor, 'editor.increaseIndentPattern')

  decreaseIndentRegexForScopeDescriptor: (scopeDescriptor) ->
    @getRegexForProperty(scopeDescriptor, 'editor.decreaseIndentPattern')

  foldEndRegexForScopeDescriptor: (scopeDescriptor) ->
    @getRegexForProperty(scopeDescriptor, 'editor.foldEndPattern')
