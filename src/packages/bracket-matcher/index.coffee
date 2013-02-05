AtomPackage = require 'atom-package'
_ = require 'underscore'
{$$} = require 'space-pen'
Range = require 'range'

module.exports =
class BracketMatcher extends AtomPackage
  startPairMatches:
    '(': ')'
    '[': ']'
    '{': '}'

  endPairMatches:
    ')': '('
    ']': '['
    '}': '{'

  pairHighlighted: false

  activate: (rootView) ->
    rootView.eachEditor (editor) => @subscribeToEditor(editor) if editor.attached

  subscribeToEditor: (editor) ->
    editor.on 'cursor:moved.bracket-matcher', => @updateMatch(editor)
    editor.on 'editor:will-be-removed', => editor.off('.bracket-matcher')

  createView: (editor, bufferPosition) ->
    pixelPosition = editor.pixelPositionForBufferPosition(bufferPosition)
    view = $$ -> @div class: 'bracket-matcher'
    view.css('top', pixelPosition.top).css('left', pixelPosition.left)
    view.width(editor.charWidth).height(editor.charHeight)

  findCurrentPair: (editor, buffer, matches) ->
    position = editor.getCursorBufferPosition()
    currentPair = buffer.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    unless matches[currentPair]
      position = position.translate([0, -1])
      currentPair = buffer.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    matchingPair = matches[currentPair]
    if matchingPair
      {position, currentPair, matchingPair}
    else
      {}

  findMatchingEndPair: (buffer, startPairPosition, startPair, endPair) ->
    scanRange = new Range(startPairPosition.translate([0, 1]), buffer.getEofPosition())
    regex = new RegExp("[#{_.escapeRegExp(startPair + endPair)}]", 'g')
    endPairPosition = null
    unpairedCount = 0
    buffer.scanInRange regex, scanRange, (match, range, {stop}) =>
      if match[0] is startPair
        unpairedCount++
      else if match[0] is endPair
        unpairedCount--
        endPairPosition = range.start
        stop() if unpairedCount < 0
    endPairPosition

  findMatchingStartPair: (buffer, endPairPosition, startPair, endPair) ->
    scanRange = new Range([0, 0], endPairPosition)
    regex = new RegExp("[#{_.escapeRegExp(startPair + endPair)}]", 'g')
    startPairPosition = null
    unpairedCount = 0
    scanner = (match, range, {stop}) =>
      if match[0] is endPair
        unpairedCount++
      else if match[0] is startPair
        unpairedCount--
        startPairPosition = range.start
        stop() if unpairedCount < 0
    buffer.scanInRange(regex, scanRange, scanner, true)
    startPairPosition

  updateMatch: (editor) ->
    return unless underlayer = editor.pane()?.find('.underlayer')

    underlayer.find('.bracket-matcher').remove() if @pairHighlighted
    @pairHighlighted = false

    return unless editor.getSelection().isEmpty()
    return if editor.isFoldedAtCursorRow()

    buffer = editor.getBuffer()
    {position, currentPair, matchingPair} = @findCurrentPair(editor, buffer, @startPairMatches)
    if position
      matchPosition = @findMatchingEndPair(buffer, position, currentPair, matchingPair)
    else
      {position, currentPair, matchingPair} = @findCurrentPair(editor, buffer, @endPairMatches)
      if position
        matchPosition = @findMatchingStartPair(buffer, position, matchingPair, currentPair)

    if position? and matchPosition?
      underlayer.append(@createView(editor, position))
      underlayer.append(@createView(editor, matchPosition))
      @pairHighlighted = true
