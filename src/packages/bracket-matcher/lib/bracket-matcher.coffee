_ = require 'underscore'
{$$} = require 'space-pen'
{Range} = require 'telepath'

module.exports =
  pairedCharacters:
    '(': ')'
    '[': ']'
    '{': '}'
    '"': '"'
    "'": "'"

  startPairMatches:
    '(': ')'
    '[': ']'
    '{': '}'

  endPairMatches:
    ')': '('
    ']': '['
    '}': '{'

  pairHighlighted: false

  activate: ->
    rootView.eachEditor (editor) => @subscribeToEditor(editor) if editor.attached
    rootView.eachEditSession (editSession) => @subscribeToEditSession(editSession)

  subscribeToEditor: (editor) ->
    editor.on 'cursor:moved.bracket-matcher', => @updateMatch(editor)
    editor.command 'editor:go-to-matching-bracket.bracket-matcher', =>
      @goToMatchingPair(editor)
    editor.on 'editor:will-be-removed', => editor.off('.bracket-matcher')
    editor.startHighlightView = @addHighlightView(editor)
    editor.endHighlightView = @addHighlightView(editor)

  addHighlightView: (editor) ->
    view = $$ -> @div class: 'bracket-matcher', style: 'display: none'
    editor.underlayer.append(view)
    view

  goToMatchingPair: (editor) ->
    return unless @pairHighlighted
    return unless underlayer = editor.getPane()?.find('.underlayer')
    return unless underlayer.isVisible()

    position = editor.getCursorBufferPosition()
    previousPosition = position.translate([0, -1])
    startPosition = underlayer.find('.bracket-matcher:first').data('bufferPosition')
    endPosition = underlayer.find('.bracket-matcher:last').data('bufferPosition')

    if position.isEqual(startPosition)
      editor.setCursorBufferPosition(endPosition.translate([0, 1]))
    else if previousPosition.isEqual(startPosition)
      editor.setCursorBufferPosition(endPosition)
    else if position.isEqual(endPosition)
      editor.setCursorBufferPosition(startPosition.translate([0, 1]))
    else if previousPosition.isEqual(endPosition)
      editor.setCursorBufferPosition(startPosition)

  moveHighlightViews: (editor, bufferRange) ->
    { start, end } = Range.fromObject(bufferRange)
    startPixelPosition = editor.pixelPositionForBufferPosition(start)
    endPixelPosition = editor.pixelPositionForBufferPosition(end)
    @moveHighlightView
      editor: editor
      view: editor.startHighlightView
      bufferPosition: start
      pixelPosition: startPixelPosition
    @moveHighlightView
      editor: editor
      view: editor.endHighlightView
      bufferPosition: end
      pixelPosition: endPixelPosition

  moveHighlightView: ({editor, view, bufferPosition, pixelPosition}) ->
    view.data('bufferPosition', bufferPosition)
    view.css
      display: 'block'
      top: pixelPosition.top
      left: pixelPosition.left
      width: editor.charWidth
      height: editor.lineHeight

  hideHighlightViews: (editor) ->
    editor.startHighlightView.hide()
    editor.endHighlightView.hide()

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
    buffer.scanInRange regex, scanRange, ({match, range, stop}) =>
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
    buffer.backwardsScanInRange regex, scanRange, ({match, range, stop}) =>
      if match[0] is endPair
        unpairedCount++
      else if match[0] is startPair
        unpairedCount--
        startPairPosition = range.start
        stop() if unpairedCount < 0
    startPairPosition

  updateMatch: (editor) ->
    return unless underlayer = editor.getPane()?.find('.underlayer')

    @hideHighlightViews(editor) if @pairHighlighted
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
      @moveHighlightViews(editor, [position, matchPosition])
      @pairHighlighted = true

  subscribeToEditSession: (editSession) ->
    @bracketMarkers = []

    _.adviseBefore editSession, 'insertText', (text) =>
      return true if editSession.hasMultipleCursors()

      cursorBufferPosition = editSession.getCursorBufferPosition()
      previousCharacter = editSession.getTextInBufferRange([cursorBufferPosition.add([0, -1]), cursorBufferPosition])
      nextCharacter = editSession.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0,1])])

      if @isOpeningBracket(text) and not editSession.getSelection().isEmpty()
        @wrapSelectionInBrackets(editSession, text)
        return false

      hasWordAfterCursor = /\w/.test(nextCharacter)
      hasWordBeforeCursor = /\w/.test(previousCharacter)

      autoCompleteOpeningBracket = @isOpeningBracket(text) and not hasWordAfterCursor and not (@isQuote(text) and hasWordBeforeCursor)
      skipOverExistingClosingBracket = false
      if @isClosingBracket(text) and nextCharacter == text
        if bracketMarker = _.find(@bracketMarkers, (marker) => marker.isValid() and marker.getBufferRange().end.isEqual(cursorBufferPosition))
          skipOverExistingClosingBracket = true

      if skipOverExistingClosingBracket
        bracketMarker.destroy()
        _.remove(@bracketMarkers, bracketMarker)
        editSession.moveCursorRight()
        false
      else if autoCompleteOpeningBracket
        editSession.insertText(text + @pairedCharacters[text])
        editSession.moveCursorLeft()
        range = [cursorBufferPosition, cursorBufferPosition.add([0, text.length])]
        @bracketMarkers.push editSession.markBufferRange(range)
        false

    _.adviseBefore editSession, 'backspace', =>
      return if editSession.hasMultipleCursors()
      return unless editSession.getSelection().isEmpty()

      cursorBufferPosition = editSession.getCursorBufferPosition()
      previousCharacter = editSession.getTextInBufferRange([cursorBufferPosition.add([0, -1]), cursorBufferPosition])
      nextCharacter = editSession.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0,1])])
      if @pairedCharacters[previousCharacter] is nextCharacter
        editSession.transact =>
          editSession.moveCursorLeft()
          editSession.delete()
          editSession.delete()
        false

  wrapSelectionInBrackets: (editSession, bracket) ->
    pair = @pairedCharacters[bracket]
    editSession.mutateSelectedText (selection) =>
      return if selection.isEmpty()

      range = selection.getBufferRange()
      options = isReversed: selection.isReversed()
      selection.insertText("#{bracket}#{selection.getText()}#{pair}")
      selectionStart = range.start.add([0, 1])
      if range.start.row is range.end.row
        selectionEnd = range.end.add([0, 1])
      else
        selectionEnd = range.end
      selection.setBufferRange([selectionStart, selectionEnd], options)

  isQuote: (string) ->
    /'|"/.test(string)

  getInvertedPairedCharacters: ->
    return @invertedPairedCharacters if @invertedPairedCharacters

    @invertedPairedCharacters = {}
    for open, close of @pairedCharacters
      @invertedPairedCharacters[close] = open
    @invertedPairedCharacters

  isOpeningBracket: (string) ->
    @pairedCharacters[string]?

  isClosingBracket: (string) ->
    @getInvertedPairedCharacters()[string]?
