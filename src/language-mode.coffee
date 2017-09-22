{Range, Point} = require 'text-buffer'
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
