{$$} = require 'space-pen'
Range = require 'range'
SelectList = require 'select-list'

module.exports =
class AutocompleteView extends SelectList
  @viewClass: -> "autocomplete #{super} popover-list"

  editor: null
  currentBuffer: null
  wordList: null
  wordRegex: /\w+/g
  originalSelectionBufferRange: null
  originalCursorPosition: null
  aboveCursor: false
  filterKey: 'word'

  initialize: (@editor) ->
    super
    @handleEvents()
    @setCurrentBuffer(@editor.getBuffer())

  itemForElement: (match) ->
    $$ ->
      @li match.word

  handleEvents: ->
    @editor.on 'editor:path-changed', => @setCurrentBuffer(@editor.getBuffer())
    @editor.command 'autocomplete:attach', => @attach()
    @editor.command 'autocomplete:next', => @selectNextItem()
    @editor.command 'autocomplete:previous', => @selectPreviousItem()

    @miniEditor.preempt 'textInput', (e) =>
      text = e.originalEvent.data
      unless text.match(@wordRegex)
        @confirmSelection()
        @editor.insertText(text)
        false

  setCurrentBuffer: (@currentBuffer) ->

  selectItem: (item) ->
    super

    match = @getSelectedElement()
    @replaceSelectedTextWithMatch(match) if match

  selectNextItem: ->
    super

    false

  selectPreviousItem: ->
    super

    false

  buildWordList: () ->
    wordHash = {}
    matches = @currentBuffer.getText().match(@wordRegex)
    wordHash[word] ?= true for word in (matches or [])

    @wordList = Object.keys(wordHash)

  confirmed: (match) ->
    @editor.getSelection().clear()
    @cancel()
    return unless match
    @replaceSelectedTextWithMatch match
    position = @editor.getCursorBufferPosition()
    @editor.setCursorBufferPosition([position.row, position.column + match.suffix.length])

  cancelled: ->
    super

    @editor.abort()
    @editor.setSelectedBufferRange(@originalSelectionBufferRange)
    rootView.focus() if @miniEditor.isFocused

  attach: ->
    @editor.transact()

    @aboveCursor = false
    @originalSelectionBufferRange = @editor.getSelection().getBufferRange()
    @originalCursorPosition = @editor.getCursorScreenPosition()

    @buildWordList()
    matches = @findMatchesForCurrentSelection()
    @setArray(matches)

    if matches.length is 1
      @confirmSelection()
    else
      @editor.appendToLinesView(this)
      @setPosition()
      @miniEditor.focus()

  detach: ->
    super

    @editor.off(".autocomplete")
    @editor.focus()

  setPosition: ->
    { left, top } = @editor.pixelPositionForScreenPosition(@originalCursorPosition)
    height = @outerHeight()
    potentialTop = top + @editor.lineHeight
    potentialBottom = potentialTop - @editor.scrollTop() + height

    if @aboveCursor or potentialBottom > @editor.outerHeight()
      @aboveCursor = true
      @css(left: left, top: top - height, bottom: 'inherit')
    else
      @css(left: left, top: potentialTop, bottom: 'inherit')

  findMatchesForCurrentSelection: ->
    selection = @editor.getSelection()
    {prefix, suffix} = @prefixAndSuffixOfSelection(selection)

    if (prefix.length + suffix.length) > 0
      regex = new RegExp("^#{prefix}.+#{suffix}$", "i")
      currentWord = prefix + @editor.getSelectedText() + suffix
      for word in @wordList when regex.test(word) and word != currentWord
        {prefix, suffix, word}
    else
      []

  replaceSelectedTextWithMatch: (match) ->
    selection = @editor.getSelection()
    startPosition = selection.getBufferRange().start
    buffer = @editor.getBuffer()

    selection.deleteSelectedText()
    cursorPosition = @editor.getCursorBufferPosition()
    buffer.delete(Range.fromPointWithDelta(cursorPosition, 0, match.suffix.length))
    buffer.delete(Range.fromPointWithDelta(cursorPosition, 0, -match.prefix.length))
    @editor.insertText(match.word)

    infixLength = match.word.length - match.prefix.length - match.suffix.length
    @editor.setSelectedBufferRange([startPosition, [startPosition.row, startPosition.column + infixLength]])

  prefixAndSuffixOfSelection: (selection) ->
    selectionRange = selection.getBufferRange()
    lineRange = [[selectionRange.start.row, 0], [selectionRange.end.row, @editor.lineLengthForBufferRow(selectionRange.end.row)]]
    [prefix, suffix] = ["", ""]

    @currentBuffer.scanInRange @wordRegex, lineRange, (match, range, {stop}) ->
      stop() if range.start.isGreaterThan(selectionRange.end)

      if range.intersectsWith(selectionRange)
        prefixOffset = selectionRange.start.column - range.start.column
        suffixOffset = selectionRange.end.column - range.end.column

        prefix = match[0][0...prefixOffset] if range.start.isLessThan(selectionRange.start)
        suffix = match[0][suffixOffset..] if range.end.isGreaterThan(selectionRange.end)

    {prefix, suffix}

  populateList: ->
    super()

    @setPosition()
