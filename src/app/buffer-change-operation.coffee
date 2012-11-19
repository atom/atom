Range = require 'range'

module.exports =
class BufferChangeOperation
  buffer: null
  oldRange: null
  oldText: null
  newRange: null
  newText: null

  constructor: ({@buffer, @oldRange, @newText}) ->

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

  changeBuffer: ({ oldRange, newRange, newText, oldText }) ->
    { prefix, suffix } = @buffer.prefixAndSuffixForRange(oldRange)

    newTextLines = newText.split('\n')
    if newTextLines.length == 1
      newTextLines = [prefix + newText + suffix]
    else
      lastLineIndex = newTextLines.length - 1
      newTextLines[0] = prefix + newTextLines[0]
      newTextLines[lastLineIndex] += suffix

    @buffer.replaceLines(oldRange.start.row, oldRange.end.row, newTextLines)

    event = { oldRange, newRange, oldText, newText }
    @buffer.trigger 'change', event
    @buffer.scheduleStoppedChangingEvent()

    anchor.handleBufferChange(event) for anchor in @buffer.getAnchors()
    @buffer.trigger 'update-anchors-after-change'
    newRange

  calculateNewRange: (oldRange, newText) ->
    newRange = new Range(oldRange.start.copy(), oldRange.start.copy())
    newTextLines = newText.split('\n')
    if newTextLines.length == 1
      newRange.end.column += newText.length
    else
      lastLineIndex = newTextLines.length - 1
      newRange.end.row += lastLineIndex
      newRange.end.column = newTextLines[lastLineIndex].length
    newRange
