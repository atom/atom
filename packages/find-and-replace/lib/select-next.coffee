_ = require 'underscore-plus'
{CompositeDisposable, Range} = require 'atom'

# Find and select the next occurrence of the currently selected text.
#
# The word under the cursor will be selected if the selection is empty.
module.exports =
class SelectNext
  selectionRanges: null

  constructor: (@editor) ->
    @selectionRanges = []

  findAndSelectNext: ->
    if @editor.getLastSelection().isEmpty()
      @selectWord()
    else
      @selectNextOccurrence()

  findAndSelectAll: ->
    @selectWord() if @editor.getLastSelection().isEmpty()
    @selectAllOccurrences()

  undoLastSelection: ->
    @updateSavedSelections()

    return if @selectionRanges.length < 1

    if @selectionRanges.length > 1
      @selectionRanges.pop()
      @editor.setSelectedBufferRanges @selectionRanges
    else
      @editor.clearSelections()

    @editor.scrollToCursorPosition()

  skipCurrentSelection: ->
    @updateSavedSelections()

    return if @selectionRanges.length < 1

    if @selectionRanges.length > 1
      lastSelection = @selectionRanges.pop()
      @editor.setSelectedBufferRanges @selectionRanges
      @selectNextOccurrence(start: lastSelection.end)
    else
      @selectNextOccurrence()
      @selectionRanges.shift()
      return if @selectionRanges.length < 1
      @editor.setSelectedBufferRanges @selectionRanges

  selectWord: ->
    @editor.selectWordsContainingCursors()
    lastSelection = @editor.getLastSelection()
    if @wordSelected = @isWordSelected(lastSelection)
      disposables = new CompositeDisposable
      clearWordSelected = =>
        @wordSelected = null
        disposables.dispose()
      disposables.add lastSelection.onDidChangeRange clearWordSelected
      disposables.add lastSelection.onDidDestroy clearWordSelected

  selectAllOccurrences: ->
    range = [[0, 0], @editor.getEofBufferPosition()]
    @scanForNextOccurrence range, ({range, stop}) =>
      @addSelection(range)

  selectNextOccurrence: (options={}) ->
    startingRange = options.start ? @editor.getSelectedBufferRange().end
    range = @findNextOccurrence([startingRange, @editor.getEofBufferPosition()])
    range ?= @findNextOccurrence([[0, 0], @editor.getSelections()[0].getBufferRange().start])
    @addSelection(range) if range?

  findNextOccurrence: (scanRange) ->
    foundRange = null
    @scanForNextOccurrence scanRange, ({range, stop}) ->
      foundRange = range
      stop()
    foundRange

  addSelection: (range) ->
    reversed = @editor.getLastSelection().isReversed()
    selection = @editor.addSelectionForBufferRange(range, {reversed})
    @updateSavedSelections selection

  scanForNextOccurrence: (range, callback) ->
    selection = @editor.getLastSelection()
    text = _.escapeRegExp(selection.getText())

    if @wordSelected
      nonWordCharacters = atom.config.get('editor.nonWordCharacters')
      text = "(^|[ \t#{_.escapeRegExp(nonWordCharacters)}]+)#{text}(?=$|[\\s#{_.escapeRegExp(nonWordCharacters)}]+)"

    @editor.scanInBufferRange new RegExp(text, 'g'), range, (result) ->
      if prefix = result.match[1]
        result.range = result.range.translate([0, prefix.length], [0, 0])
      callback(result)

  updateSavedSelections: (selection=null) ->
    selections = @editor.getSelections()
    @selectionRanges = [] if selections.length < 3
    if @selectionRanges.length is 0
      @selectionRanges.push s.getBufferRange() for s in selections
    else if selection
      selectionRange = selection.getBufferRange()
      return if @selectionRanges.some (existingRange) -> existingRange.isEqual(selectionRange)
      @selectionRanges.push selectionRange

  isNonWordCharacter: (character) ->
    nonWordCharacters = atom.config.get('editor.nonWordCharacters')
    new RegExp("[ \t#{_.escapeRegExp(nonWordCharacters)}]").test(character)

  isNonWordCharacterToTheLeft: (selection) ->
    selectionStart = selection.getBufferRange().start
    range = Range.fromPointWithDelta(selectionStart, 0, -1)
    @isNonWordCharacter(@editor.getTextInBufferRange(range))

  isNonWordCharacterToTheRight: (selection) ->
    selectionEnd = selection.getBufferRange().end
    range = Range.fromPointWithDelta(selectionEnd, 0, 1)
    @isNonWordCharacter(@editor.getTextInBufferRange(range))

  isWordSelected: (selection) ->
    if selection.getBufferRange().isSingleLine()
      selectionRange = selection.getBufferRange()
      lineRange = @editor.bufferRangeForBufferRow(selectionRange.start.row)
      nonWordCharacterToTheLeft = _.isEqual(selectionRange.start, lineRange.start) or
        @isNonWordCharacterToTheLeft(selection)
      nonWordCharacterToTheRight = _.isEqual(selectionRange.end, lineRange.end) or
        @isNonWordCharacterToTheRight(selection)
      containsOnlyWordCharacters = not @isNonWordCharacter(selection.getText())

      nonWordCharacterToTheLeft and nonWordCharacterToTheRight and containsOnlyWordCharacters
    else
      false
