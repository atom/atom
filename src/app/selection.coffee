Range = require 'range'
Anchor = require 'anchor'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

module.exports =
class Selection
  anchor: null
  wordwise: false
  initialScreenRange: null

  constructor: ({@cursor, @editSession}) ->
    @cursor.selection = this

    @cursor.on 'moved.selection', ({bufferChange}) =>
      @screenRangeChanged() unless bufferChange

    @cursor.on 'destroyed.selection', =>
      @cursor = null
      @destroy()

  destroy: ->
    if @cursor
      @cursor.off('.selection')
      @cursor.destroy()
    @anchor?.destroy()
    @editSession.removeSelection(this)
    @trigger 'destroyed'

  finalize: ->
    @initialScreenRange = null unless @initialScreenRange?.isEqual(@getScreenRange())
    if @isEmpty()
      @wordwise = false
      @linewise = false

  isEmpty: ->
    @getBufferRange().isEmpty()

  isReversed: ->
    not @isEmpty() and @cursor.getBufferPosition().isLessThan(@anchor.getBufferPosition())

  isSingleScreenLine: ->
    @getScreenRange().isSingleLine()

  autoscrolled: ->
    @needsAutoscroll = false

  getScreenRange: ->
    if @anchor
      new Range(@anchor.getScreenPosition(), @cursor.getScreenPosition())
    else
      new Range(@cursor.getScreenPosition(), @cursor.getScreenPosition())

  setScreenRange: (screenRange, options) ->
    bufferRange = editSession.bufferRangeForScreenRange(screenRange)
    @setBufferRange(bufferRange, options)

  getBufferRange: ->
    if @anchor
      new Range(@anchor.getBufferPosition(), @cursor.getBufferPosition())
    else
      new Range(@cursor.getBufferPosition(), @cursor.getBufferPosition())

  setBufferRange: (bufferRange, options={}) ->
    bufferRange = Range.fromObject(bufferRange)
    { start, end } = bufferRange
    [start, end] = [end, start] if options.reverse ? @isReversed()

    @needsAutoscroll = options.autoscroll

    @editSession.destroyFoldsIntersectingBufferRange(bufferRange) unless options.preserveFolds
    @placeAnchor() unless @anchor
    @modifySelection =>
      @anchor.setBufferPosition(start, autoscroll: false)
      @cursor.setBufferPosition(end, autoscroll: false)

  getBufferRowRange: ->
    range = @getBufferRange()
    start = range.start.row
    end = range.end.row
    end = Math.max(start, end - 1) if range.end.column == 0
    [start, end]

  screenRangeChanged: ->
    screenRange = @getScreenRange()
    @trigger 'screen-range-changed', screenRange
    @cursor?.setVisible(screenRange.isEmpty())

  getText: ->
    @editSession.buffer.getTextInRange(@getBufferRange())

  clear: ->
    return unless @anchor
    @anchor.destroy()
    @anchor = null
    @screenRangeChanged()

  selectWord: ->
    @setBufferRange(@cursor.getCurrentWordBufferRange())
    @wordwise = true
    @initialScreenRange = @getScreenRange()

  expandOverWord: ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentWordBufferRange()))

  selectLine: (row=@cursor.getBufferPosition().row) ->
    range = @editSession.bufferRangeForBufferRow(row, includeNewline: true)
    @setBufferRange(range)
    @linewise = true
    @wordwise = false
    @initialScreenRange = @getScreenRange()

  expandOverLine: ->
    range = @getBufferRange().union(@cursor.getCurrentLineBufferRange(includeNewline: true))
    @setBufferRange(range)

  selectToScreenPosition: (position) ->
    @modifySelection =>
      if @initialScreenRange
        if position.isLessThan(@initialScreenRange.start)
          @anchor.setScreenPosition(@initialScreenRange.end)
          @cursor.setScreenPosition(position)
        else
          @anchor.setScreenPosition(@initialScreenRange.start)
          @cursor.setScreenPosition(position)
      else
        @cursor.setScreenPosition(position)

      if @linewise
        @expandOverLine()
      else if @wordwise
        @expandOverWord()

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
    @setBufferRange(@editSession.buffer.getRange(), autoscroll: false)

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
    text = @normalizeIndent(text, options) if options.normalizeIndent
    @clear()
    newBufferRange = @editSession.buffer.change(oldBufferRange, text)
    if options.select
      @setBufferRange(newBufferRange, reverse: wasReversed)
    else
      @cursor.setBufferPosition(newBufferRange.end, skipAtomicTokens: true) if wasReversed

    if options.autoIndent
      if text == '\n'
        @editSession.autoIndentBufferRow(newBufferRange.end.row)
      else
        @editSession.autoDecreaseIndentForRow(newBufferRange.start.row)

  indent: ({ autoIndent }={})->
    { row, column } = @cursor.getBufferPosition()

    if @isEmpty()
      @cursor.skipLeadingWhitespace()
      desiredIndent = @editSession.suggestedIndentForBufferRow(row)
      delta = desiredIndent - @cursor.getIndentLevel()

      if autoIndent and delta > 0
        @insertText(@editSession.buildIndentString(delta))
      else
        @insertText(@editSession.getTabText())
    else
      @indentSelectedRows()

  indentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    for row in [start..end]
      @editSession.buffer.insert([row, 0], @editSession.getTabText()) unless @editSession.buffer.lineLengthForRow(row) == 0

  normalizeIndent: (text, options) ->
    return text unless /\n/.test(text)

    currentBufferRow = @cursor.getBufferRow()
    currentBufferColumn = @cursor.getBufferColumn()
    lines = text.split('\n')
    currentBasis = options.indentBasis ? @editSession.indentLevelForLine(lines[0])
    lines[0] = lines[0].replace(/^\s*/, '') # strip leading space from first line

    normalizedLines = []

    textPrecedingCursor = @editSession.buffer.getTextInRange([[currentBufferRow, 0], [currentBufferRow, currentBufferColumn]])
    insideExistingLine = textPrecedingCursor.match(/\S/)

    if insideExistingLine
      desiredBasis = @editSession.indentationForBufferRow(currentBufferRow)
    else if options.autoIndent
      desiredBasis = @editSession.suggestedIndentForBufferRow(currentBufferRow)
    else
      desiredBasis = @cursor.getIndentLevel()

    for line, i in lines
      if i == 0
        if insideExistingLine
          delta = 0
        else
          delta = desiredBasis - @cursor.getIndentLevel()
      else
        delta = desiredBasis - currentBasis

      normalizedLines.push(@adjustIndentationForLine(line, delta))

    normalizedLines.join('\n')

  adjustIndentationForLine: (line, delta) ->
    currentIndentLevel = @editSession.indentLevelForLine(line)
    desiredIndentLevel = Math.max(0, currentIndentLevel + delta)
    desiredIndentString = @editSession.buildIndentString(desiredIndentLevel)
    line.replace(/^[\t ]*/, desiredIndentString)

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

  backspaceToBeginningOfLine: ->
    @selectToBeginningOfLine()
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

  outdentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    buffer = @editSession.buffer
    leadingTabRegex = new RegExp("^ {1,#{@editSession.getTabLength()}}|\t")
    for row in [start..end]
      if matchLength = buffer.lineForRow(row).match(leadingTabRegex)?[0].length
        buffer.delete [[row, 0], [row, matchLength]]

  autoIndentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    @editSession.autoIndentBufferRows(start, end)

  toggleLineComments: ->
    @modifySelection =>
      @editSession.toggleLineCommentsForBufferRows(@getBufferRowRange()...)

  cutToEndOfLine: (maintainPasteboard) ->
    @selectToEndOfLine() if @isEmpty()
    @cut(maintainPasteboard)

  cut: (maintainPasteboard=false) ->
    @copy(maintainPasteboard)
    @delete()

  copy: (maintainPasteboard=false) ->
    return if @isEmpty()
    text = @editSession.buffer.getTextInRange(@getBufferRange())
    if maintainPasteboard
      [currentText, metadata] = pasteboard.read()
      text = currentText + '\n' + text
    else
      metadata = { indentBasis: @editSession.indentationForBufferRow(@getBufferRange().start.row) }

    pasteboard.write(text, metadata)

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
    @placeAnchor() unless @anchor
    @anchor.pauseEvents()
    @cursor.pauseEvents()
    fn()
    @anchor.resumeEvents()
    @cursor.resumeEvents()
    @retainSelection = false

  placeAnchor: ->
    @anchor = @editSession.addAnchor(strong: true)
    @anchor.setScreenPosition(@cursor.getScreenPosition())
    @anchor.on 'moved.selection', => @screenRangeChanged()

  intersectsBufferRange: (bufferRange) ->
    @getBufferRange().intersectsWith(bufferRange)

  intersectsWith: (otherSelection) ->
    @getScreenRange().intersectsWith(otherSelection.getScreenRange())

  merge: (otherSelection, options) ->
    @setBufferRange(@getBufferRange().union(otherSelection.getBufferRange()), options)
    otherSelection.destroy()

_.extend Selection.prototype, EventEmitter
