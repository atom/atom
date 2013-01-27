Range = require 'range'
_ = require 'underscore'

module.exports =
class BufferChangeOperation
  buffer: null
  oldRange: null
  oldText: null
  newRange: null
  newText: null

  constructor: ({@buffer, @oldRange, @newText, @options}) ->
    @options ?= {}

  do: ->
    @oldText = @buffer.getTextInRange(@oldRange)
    @newRange = @calculateNewRange(@oldRange, @newText)
    @changeBuffer
      oldRange: @oldRange
      newRange: @newRange
      oldText: @oldText
      newText: @newText

  undo: ->
    @changeBuffer
      oldRange: @newRange
      newRange: @oldRange
      oldText: @newText
      newText: @oldText

  splitLines: (text) ->
    lines = text.split('\n')
    lineEndings = []
    for line, index in lines
      if _.endsWith(line, '\r')
        lines[index] = line[0..-2]
        lineEndings[index] = '\r\n'
      else
        lineEndings[index] = '\n'
    {lines, lineEndings}

  changeBuffer: ({ oldRange, newRange, newText, oldText }) ->
    { prefix, suffix } = @buffer.prefixAndSuffixForRange(oldRange)

    {lines, lineEndings} = @splitLines(newText)
    lastLineIndex = lines.length - 1

    if lines.length == 1
      lines = [prefix + newText + suffix]
    else
      lines[0] = prefix + lines[0]
      lines[lastLineIndex] += suffix

    startRow = oldRange.start.row
    endRow = oldRange.end.row

    normalizeLineEndings = @options.normalizeLineEndings ? true
    if normalizeLineEndings and suggestedLineEnding = @buffer.suggestedLineEndingForRow(startRow)
      lineEndings[index] = suggestedLineEnding for index in [0..lastLineIndex]
    @buffer.lines[startRow..endRow] = lines
    @buffer.lineEndings[startRow..endRow] = lineEndings
    @buffer.cachedMemoryContents = null
    @buffer.conflict = false if @buffer.conflict and !@buffer.isModified()

    event = { oldRange, newRange, oldText, newText }
    @buffer.trigger 'changed', event
    @buffer.scheduleStoppedChangingEvent()
    @buffer.updateAnchors(event)
    newRange

  calculateNewRange: (oldRange, newText) ->
    newRange = new Range(oldRange.start.copy(), oldRange.start.copy())
    {lines} = @splitLines(newText)
    if lines.length == 1
      newRange.end.column += newText.length
    else
      lastLineIndex = lines.length - 1
      newRange.end.row += lastLineIndex
      newRange.end.column = lines[lastLineIndex].length
    newRange
