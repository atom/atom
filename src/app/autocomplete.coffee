{View, $$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'
Range = require 'range'
Editor = require 'editor'

module.exports =
class Autocomplete extends View
  @content: ->
    @div id: 'autocomplete', =>
      @ol outlet: 'matchesList'
      @subview 'miniEditor', new Editor

  editor: null
  miniEditor: null
  currentBuffer: null
  wordList: null
  wordRegex: /\w+/g
  matches: null
  currentMatchIndex: null
  isAutocompleting: false
  currentSelectionBufferRange: null
  originalSelectionBufferRange: null
  originalSelectedText: null

  initialize: (@editor) ->
    requireStylesheet 'autocomplete.css'
    @handleEvents()
    @setCurrentBuffer(@editor.buffer)

  handleEvents: ->
    @editor.on 'buffer-path-change', => @setCurrentBuffer(@editor.buffer)
    @editor.on 'before-remove', => @currentBuffer?.off '.autocomplete'

    @editor.on 'autocomplete:toggle', => @attach()
    @on 'autocomplete:toggle', => @detach()
    @on 'autocomplete:confirm', => @confirm()
    @on 'autocomplete:cancel', => @cancel()

    @miniEditor.preempt 'move-up', =>
      @selectPreviousMatch()
      false

    @miniEditor.preempt 'move-down', =>
      @selectNextMatch()
      false

  setCurrentBuffer: (buffer) ->
    @currentBuffer?.off '.autocomplete'
    @currentBuffer = buffer
    @buildWordList()
    @currentBuffer.on 'change.autocomplete', (e) => @bufferChanged(e)

  confirm: ->
    @editor.getSelection().clearSelection()
    @detach()
    match = @selectedMatch()
    position = @editor.getCursorBufferPosition()
    @editor.setCursorBufferPosition([position.row, position.column + match.suffix.length])

  cancel: ->
    @detach()
    if @currentSelectionBufferRange
      @editor.setSelectionBufferRange(@currentSelectionBufferRange)
      @editor.getSelection().insertText @originalSelectedText
      @editor.setSelectionBufferRange(@originalSelectionBufferRange)

  attach: ->
    @editor.on 'focus.autocomplete', => @cancel()

    @originalSelectedText = @editor.getSelectedText()
    @originalSelectionBufferRange = @editor.getSelection().getBufferRange()
    @buildMatchList()
    @selectMatchAtIndex(0) if @matches.length > 0

    cursorScreenPosition = @editor.getCursorScreenPosition()
    {left, top} = @editor.pixelOffsetForScreenPosition(cursorScreenPosition)
    @css {left: left, top: top + @editor.lineHeight}
    $(document.body).append(this)
    @miniEditor.focus()

  detach: ->
    @editor.off(".autocomplete")
    @editor.focus()
    super

  selectPreviousMatch: ->
    previousIndex = @currentMatchIndex - 1
    previousIndex = @matches.length - 1 if previousIndex < 0
    @selectMatchAtIndex(previousIndex)

  selectNextMatch: ->
    nextIndex = (@currentMatchIndex + 1) % @matches.length
    @selectMatchAtIndex(nextIndex)

  selectMatchAtIndex: (index) ->
    @currentMatchIndex = index
    @matchesList.find("li").removeClass "selected"
    @matchesList.find("li:eq(#{index})").addClass "selected"
    @completeUsingMatch(@selectedMatch())

  selectedMatch: ->
    @matches[@currentMatchIndex]

  bufferChanged: (e) ->
    @buildWordList() unless @isAutocompleting

  buildMatchList: ->
    selection = @editor.getSelection()
    {prefix, suffix} = @prefixAndSuffixOfSelection(selection)
    if (prefix.length + suffix.length) == 0
      @matches = []
      return

    currentWord = prefix + @editor.getSelectedText() + suffix

    @matches = (match for match in @wordMatches(prefix, suffix) when match.word != currentWord)

    @matchesList.empty()
    if @matches.length > 0
      @matchesList.append($$ -> @li match.word) for match in @matches
    else
      @matchesList.append($$ -> @li "No matches found")

  buildWordList: () ->
    @wordList = _.unique(@currentBuffer.getText().match(@wordRegex))

  wordMatches: (prefix, suffix) ->
    regex = new RegExp("^#{prefix}(.+)#{suffix}$", "i")
    for word in @wordList when regex.test(word)
      match = regex.exec(word)
      {prefix, suffix, word, infix: match[1]}

  completeUsingMatch: (match) ->
    selection = @editor.getSelection()
    startPosition = selection.getBufferRange().start
    @isAutocompleting = true
    @editor.insertText(match.infix)
    @editor.setSelectionBufferRange([startPosition, [startPosition.row, startPosition.column + match.infix.length]])
    @currentSelectionBufferRange = @editor.getSelection().getBufferRange()
    @isAutocompleting = false

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
