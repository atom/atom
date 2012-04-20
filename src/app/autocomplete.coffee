{View, $$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'
Range = require 'range'
Editor = require 'editor'
fuzzyFilter = require 'fuzzy-filter'

module.exports =
class Autocomplete extends View
  @content: ->
    @div class: 'autocomplete', =>
      @ol outlet: 'matchesList'
      @subview 'miniEditor', new Editor(mini: true)

  editor: null
  miniEditor: null
  currentBuffer: null
  wordList: null
  wordRegex: /\w+/g
  allMatches: null
  filteredMatches: null
  currentMatchIndex: null
  isAutocompleting: false
  originalSelectionBufferRange: null
  originalSelectedText: null

  @activate: (rootView) ->
    new Autocomplete(editor) for editor in rootView.editors()
    rootView.on 'editor-open', (e, editor) -> new Autocomplete(editor)

  initialize: (@editor) ->
    requireStylesheet 'autocomplete.css'
    @handleEvents()
    @setCurrentBuffer(@editor.buffer)

  handleEvents: ->
    @editor.on 'buffer-path-change', => @setCurrentBuffer(@editor.buffer)
    @editor.on 'before-remove', => @currentBuffer?.off '.autocomplete'

    @editor.on 'autocomplete:attach', => @attach()
    @editor.on 'autocomplete:cancel', => @cancel()
    @on 'autocomplete:confirm', => @confirm()

    @miniEditor.buffer.on 'change', (e) =>
      @filterMatches() if @parent()[0]

    @miniEditor.preempt 'move-up', =>
      @selectPreviousMatch()
      false

    @miniEditor.preempt 'move-down', =>
      @selectNextMatch()
      false

    @miniEditor.preempt 'textInput', (e) =>
      text = e.originalEvent.data
      unless text.match(@wordRegex)
        @confirm()
        @editor.insertText(text)
        false

  setCurrentBuffer: (buffer) ->
    @currentBuffer?.off '.autocomplete'
    @currentBuffer = buffer
    @buildWordList()
    @currentBuffer.on 'change.autocomplete', (e) =>
      @buildWordList() unless @isAutocompleting

  buildWordList: () ->
    @wordList = _.unique(@currentBuffer.getText().match(@wordRegex))

  confirm: ->
    @editor.getSelection().clearSelection()
    @detach()
    return unless match = @selectedMatch()
    position = @editor.getCursorBufferPosition()
    @editor.setCursorBufferPosition([position.row, position.column + match.suffix.length])

  cancel: ->
    @detach()
    @editor.getSelection().insertText @originalSelectedText
    @editor.setSelectionBufferRange(@originalSelectionBufferRange)

  attach: ->
    @editor.on 'focus.autocomplete', => @cancel()

    @originalSelectedText = @editor.getSelectedText()
    @originalSelectionBufferRange = @editor.getSelection().getBufferRange()
    @allMatches = @findMatchesForCurrentSelection()

    cursorScreenPosition = @editor.getCursorScreenPosition()
    {left, top} = @editor.pixelPositionForScreenPosition(cursorScreenPosition)
    @css {left: left, top: top + @editor.lineHeight}

    @filterMatches()
    @editor.lines.append(this)
    @miniEditor.focus()

  detach: ->
    @editor.off(".autocomplete")
    @editor.focus()
    super
    @miniEditor.buffer.setText('')

  selectPreviousMatch: ->
    previousIndex = @currentMatchIndex - 1
    previousIndex = @filteredMatches.length - 1 if previousIndex < 0
    @selectMatchAtIndex(previousIndex)

  selectNextMatch: ->
    nextIndex = (@currentMatchIndex + 1) % @filteredMatches.length
    @selectMatchAtIndex(nextIndex)

  selectMatchAtIndex: (index) ->
    @currentMatchIndex = index
    @matchesList.find("li").removeClass "selected"
    @matchesList.find("li:eq(#{index})").addClass "selected"
    @replaceSelectedTextWithMatch @selectedMatch()

  selectedMatch: ->
    @filteredMatches[@currentMatchIndex]

  filterMatches: ->
    @filteredMatches = fuzzyFilter(@allMatches, @miniEditor.getText(), key: 'word')
    @renderMatchList()

  renderMatchList: ->
    @matchesList.empty()
    if @filteredMatches.length > 0
      @matchesList.append($$ -> @li match.word) for match in @filteredMatches
    else
      @matchesList.append($$ -> @li "No matches found")

    @selectMatchAtIndex(0) if @filteredMatches.length > 0

  findMatchesForCurrentSelection: ->
    selection = @editor.getSelection()
    {prefix, suffix} = @prefixAndSuffixOfSelection(selection)

    if (prefix.length + suffix.length) > 0
      regex = new RegExp("^#{prefix}(.+)#{suffix}$", "i")
      currentWord = prefix + @editor.getSelectedText() + suffix
      for word in @wordList when regex.test(word) and word != currentWord
        match = regex.exec(word)
        {prefix, suffix, word, infix: match[1]}
    else
      []

  replaceSelectedTextWithMatch: (match) ->
    selection = @editor.getSelection()
    startPosition = selection.getBufferRange().start
    @isAutocompleting = true
    @editor.insertText(match.infix)
    @editor.setSelectionBufferRange([startPosition, [startPosition.row, startPosition.column + match.infix.length]])
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
