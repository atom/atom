Range = require 'range'
Anchor = require 'anchor'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

module.exports =
class Selection
  anchor: null

  constructor: ({@cursor, @editSession}) ->
    @cursor.selection = this

    @cursor.on 'change-screen-position.selection', (e) =>
      @trigger 'change-screen-range', @getScreenRange() unless e.bufferChanged

    @cursor.on 'destroy.selection', =>
      @cursor = null
      @destroy()

  destroy: ->
    if @cursor
      @cursor.off('.selection')
      @cursor.destroy()
    @anchor?.destroy()
    @editSession.removeSelection(this)
    @trigger 'destroy'

  isEmpty: ->
    @getBufferRange().isEmpty()

  isReversed: ->
    not @isEmpty() and @cursor.getBufferPosition().isLessThan(@anchor.getBufferPosition())

  isSingleScreenLine: ->
    @getScreenRange().isSingleLine()

  getScreenRange: ->
    if @anchor
      new Range(@anchor.getScreenPosition(), @cursor.getScreenPosition())
    else
      new Range(@cursor.getScreenPosition(), @cursor.getScreenPosition())

  setScreenRange: (screenRange, options={}) ->
    screenRange = Range.fromObject(screenRange)
    { start, end } = screenRange
    [start, end] = [end, start] if options.reverse

    @modifyScreenRange =>
      @placeAnchor() unless @anchor
      @modifySelection =>
        @anchor.setScreenPosition(start)
        @cursor.setScreenPosition(end)

  setBufferRange: (bufferRange, options={}) ->
    bufferRange = Range.fromObject(bufferRange)
    { start, end } = bufferRange
    [start, end] = [end, start] if options.reverse

    @modifyScreenRange =>
      @editSession.destroyFoldsIntersectingBufferRange(bufferRange) unless options.preserveFolds
      @placeAnchor() unless @anchor
      @modifySelection =>
        @anchor.setBufferPosition(start, options)
        @cursor.setBufferPosition(end, options)

  getBufferRange: ->
    if @anchor
      new Range(@anchor.getBufferPosition(), @cursor.getBufferPosition())
    else
      new Range(@cursor.getBufferPosition(), @cursor.getBufferPosition())

  getText: ->
    @editSession.buffer.getTextInRange(@getBufferRange())

  clear: ->
    @modifyScreenRange =>
      @anchor?.destroy()
      @anchor = null

  selectWord: ->
    @setBufferRange(@cursor.getCurrentWordBufferRange())

  expandOverWord: ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentWordBufferRange()))

  selectLine: (row=@cursor.getBufferPosition().row) ->
    startPosition = [row, 0]
    if @editSession.getLastBufferRow() == row
      endPosition = [row, Infinity]
    else
      endPosition = [row+1, 0]
    @setBufferRange [startPosition, endPosition]

  expandOverLine: ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentLineBufferRange()))

  selectToScreenPosition: (position) ->
    @modifySelection => @cursor.setScreenPosition(position)

  selectToBufferPosition: (position) ->
    @modifySelection => @cursor.setBufferPosition(position)

  selectRight: ->
    @modifySelection => @cursor.moveRight()

  selectLeft: ->
    @modifySelection => @cursor.moveLeft()

  selectUp: ->
    @modifySelection => @cursor.moveUp()

  selectDown: ->
    @modifySelection => @cursor.moveDown()

  selectToTop: ->
    @modifySelection => @cursor.moveToTop()

  selectToBottom: ->
    @modifySelection => @cursor.moveToBottom()

  selectAll: ->
    @setBufferRange(@editSession.buffer.getRange())

  selectToBeginningOfLine: ->
    @modifySelection => @cursor.moveToBeginningOfLine()

  selectToEndOfLine: ->
    @modifySelection => @cursor.moveToEndOfLine()

  selectToBeginningOfWord: ->
    @modifySelection => @cursor.moveToBeginningOfWord()

  selectToEndOfWord: ->
    @modifySelection => @cursor.moveToEndOfWord()

  insertText: (text, options={}) ->
    oldBufferRange = @getBufferRange()
    @editSession.destroyFoldsContainingBufferRow(oldBufferRange.end.row)
    wasReversed = @isReversed()
    text = @normalizeIndent(text) if options.normalizeIndent
    @clear()
    newBufferRange = @editSession.buffer.change(oldBufferRange, text)
    @cursor.setBufferPosition(newBufferRange.end, skipAtomicTokens: true) if wasReversed

    if @editSession.autoIndent and options.autoIndent
      if text == '\n'
        @editSession.autoIndentBufferRow(newBufferRange.end.row)
      else
        @editSession.autoDecreaseIndentForRow(newBufferRange.start.row)

  normalizeIndent: (text) ->
    return text unless /\n/.test(text)

    currentBufferRow = @cursor.getBufferRow()
    currentBufferColumn = @cursor.getBufferColumn()
    lines = text.split('\n')
    normalizedLines = []

    textPrecedingCursor = @editSession.buffer.getTextInRange([[currentBufferRow, 0], [currentBufferRow, currentBufferColumn]])
    insideExistingLine = textPrecedingCursor.match(/\S/)

    if insideExistingLine
      desiredBase = @editSession.indentationForBufferRow(currentBufferRow)
    else if @editSession.autoIndent
      desiredBase = @editSession.suggestedIndentForBufferRow(currentBufferRow)
    else
      desiredBase = currentBufferColumn

    currentBase = lines[0].match(/\s*/)[0].length
    delta = desiredBase - currentBase

    for line, i in lines
      if i == 0
        if insideExistingLine
          firstLineDelta = -line.length # remove all leading whitespace
        else
          firstLineDelta = delta - currentBufferColumn

        normalizedLines.push(@adjustIndentationForLine(line, firstLineDelta))
      else
        normalizedLines.push(@adjustIndentationForLine(line, delta))

    normalizedLines.join('\n')

  adjustIndentationForLine: (line, delta) ->
    if delta > 0
      new Array(delta + 1).join(' ') + line
    else if delta < 0
      line.replace(new RegExp("^ {0,#{Math.abs(delta)}}"), '')
    else
      line

  backspace: ->
    if @isEmpty() and not @editSession.isFoldedAtScreenRow(@cursor.getScreenRow())
      if @cursor.isAtBeginningOfLine() and @editSession.isFoldedAtScreenRow(@cursor.getScreenRow() - 1)
        @selectToBufferPosition([@cursor.getBufferRow() - 1, Infinity])
      else
        @selectLeft()

    @deleteSelectedText()

  backspaceToBeginningOfWord: ->
    @selectToBeginningOfWord() if @isEmpty()
    @deleteSelectedText()

  delete: ->
    if @isEmpty()
      if @cursor.isAtEndOfLine() and fold = @editSession.largestFoldStartingAtScreenRow(@cursor.getScreenRow() + 1)
        @selectToBufferPosition(fold.getBufferRange().end)
      else
        @selectRight()
    @deleteSelectedText()

  deleteToEndOfWord: ->
    @selectToEndOfWord() if @isEmpty()
    @deleteSelectedText()

  deleteSelectedText: ->
    bufferRange = @getBufferRange()
    if fold = @editSession.largestFoldContainingBufferRow(bufferRange.end.row)
      includeNewline = bufferRange.start.column == 0 or bufferRange.start.row >= fold.startRow
      bufferRange = bufferRange.union(fold.getBufferRange({ includeNewline }))

    @modifyScreenRange =>
      @editSession.buffer.delete(bufferRange) unless bufferRange.isEmpty()
      @cursor?.setBufferPosition(bufferRange.start)

  deleteLine: ->
    if @isEmpty()
      start = @cursor.getScreenRow()
      range = @editSession.bufferRowsForScreenRows(start, start + 1)
      if range[1]
        @editSession.buffer.deleteRows(range[0], range[1] - 1)
      else
        @editSession.buffer.deleteRow(range[0])
    else
      range = @getBufferRange()
      start = range.start.row
      end = range.end.row
      if end isnt @editSession.buffer.getLastRow() and range.end.column is 0
        end--
      @editSession.buffer.deleteRows(start, end)

  indentSelectedRows: ->
    range = @getBufferRange()
    for row in [range.start.row..range.end.row]
      @editSession.buffer.insert([row, 0], @editSession.getTabText()) unless @editSession.buffer.lineLengthForRow(row) == 0

  outdentSelectedRows: ->
    range = @getBufferRange()
    buffer = @editSession.buffer
    leadingTabRegex = new RegExp("^#{@editSession.getTabText()}")
    for row in [range.start.row..range.end.row]
      if leadingTabRegex.test buffer.lineForRow(row)
        buffer.delete [[row, 0], [row, @editSession.tabLength]]

  toggleLineComments: ->
    @modifySelection =>
      @editSession.toggleLineCommentsInRange(@getBufferRange())

  cutToEndOfLine: (maintainPasteboard) ->
    @selectToEndOfLine() if @isEmpty()
    @cut(maintainPasteboard)

  cut: (maintainPasteboard=false) ->
    @copy(maintainPasteboard)
    @delete()

  copy: (maintainPasteboard=false) ->
    return if @isEmpty()
    text = @editSession.buffer.getTextInRange(@getBufferRange())
    text = $native.readFromPasteboard() + "\n" + text if maintainPasteboard
    $native.writeToPasteboard text

  fold: ->
    range = @getBufferRange()
    @editSession.createFold(range.start.row, range.end.row)
    @cursor.setBufferPosition([range.end.row + 1, 0])

  autoIndentText: (text) ->
    @editSession.autoIndentTextAfterBufferPosition(text, @cursor.getBufferPosition())

  autoOutdent: ->
    @editSession.autoOutdentBufferRow(@cursor.getBufferRow())

  modifySelection: (fn) ->
    @retainSelection = true
    @view?.retainSelection = true
    @placeAnchor() unless @anchor
    fn()
    @retainSelection = false
    @view?.retainSelection = false

  modifyScreenRange: (fn) ->
    oldScreenRange = @getScreenRange()
    fn()
    if @cursor
      newScreenRange = @getScreenRange()
      @trigger 'change-screen-range', newScreenRange unless oldScreenRange.isEqual(newScreenRange)

  placeAnchor: ->
    @anchor = @editSession.addAnchor(strong: true)
    @anchor.setScreenPosition(@cursor.getScreenPosition())
    @anchor.on 'change-screen-position.selection', => @trigger 'change-screen-range'

  intersectsBufferRange: (bufferRange) ->
    @getBufferRange().intersectsWith(bufferRange)

  intersectsWith: (otherSelection) ->
    @getScreenRange().intersectsWith(otherSelection.getScreenRange())

  merge: (otherSelection, options) ->
    @setScreenRange(@getScreenRange().union(otherSelection.getScreenRange()), options)
    otherSelection.destroy()

_.extend Selection.prototype, EventEmitter
