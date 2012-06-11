Range = require 'range'
Anchor = require 'new-anchor'
EventEmitter = require 'event-emitter'
AceOutdentAdaptor = require 'ace-outdent-adaptor'
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
    @editSession.removeSelection(this)
    @trigger 'destroy'

  isEmpty: ->
    @getBufferRange().isEmpty()

  isReversed: ->
    not @isEmpty() and @cursor.getBufferPosition().isLessThan(@anchor.getBufferPosition())

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
    @modifyScreenRange => @anchor = null

  selectWord: ->
    @setBufferRange(@cursor.getCurrentWordBufferRange())

  expandOverWord: ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentWordBufferRange()))

  selectLine: (row=@cursor.getBufferPosition().row) ->
    @setBufferRange(@editSession.bufferRangeForBufferRow(row))

  expandOverLine: ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentLineBufferRange()))

  selectToScreenPosition: (position) ->
    @modifySelection => @cursor.setScreenPosition(position)

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

  insertText: (text) ->
    { text, shouldOutdent } = @autoIndentText(text)
    oldBufferRange = @getBufferRange()
    @editSession.destroyFoldsContainingBufferRow(oldBufferRange.end.row)
    wasReversed = @isReversed()
    @clear()
    newBufferRange = @editSession.buffer.change(oldBufferRange, text)
    @cursor.setBufferPosition(newBufferRange.end, skipAtomicTokens: true) if wasReversed
    @autoOutdentText() if shouldOutdent

  backspace: ->
    @editSession.destroyFoldsContainingBufferRow(@getBufferRange().end.row)
    @selectLeft() if @isEmpty()
    @deleteSelectedText()

  backspaceToBeginningOfWord: ->
    @selectToBeginningOfWord() if @isEmpty()
    @deleteSelectedText()

  delete: ->
    @selectRight() if @isEmpty()
    @deleteSelectedText()

  deleteToEndOfWord: ->
    @selectToEndOfWord() if @isEmpty()
    @deleteSelectedText()

  deleteSelectedText: ->
    bufferRange = @getBufferRange()
    @editSession.buffer.delete(bufferRange) unless bufferRange.isEmpty()
    @clear() if @cursor

  indentSelectedRows: ->
    range = @getBufferRange()
    for row in [range.start.row..range.end.row]
      @editSession.buffer.insert([row, 0], @editSession.tabText) unless @editSession.buffer.lineLengthForRow(row) == 0

  outdentSelectedRows: ->
    range = @getBufferRange()
    buffer = @editSession.buffer
    leadingTabRegex = new RegExp("^#{@editSession.tabText}")
    for row in [range.start.row..range.end.row]
      if leadingTabRegex.test buffer.lineForRow(row)
        buffer.delete [[row, 0], [row, @editSession.tabText.length]]

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
    if @editSession.autoIndent
      mode = @editSession.getCurrentMode()
      row = @cursor.getCurrentScreenRow()
      state = @editSession.stateForScreenRow(row)
      lineBeforeCursor = @cursor.getCurrentBufferLine()[0...@cursor.getBufferPosition().column]
      if text[0] == "\n"
        indent = mode.getNextLineIndent(state, lineBeforeCursor, @editSession.tabText)
        text = text[0] + indent + text[1..]
      else if mode.checkOutdent(state, lineBeforeCursor, text)
        shouldOutdent = true

    {text, shouldOutdent}

  autoOutdentText: ->
    screenRow = @cursor.getCurrentScreenRow()
    bufferRow = @cursor.getCurrentBufferRow()
    state = @editSession.stateForScreenRow(screenRow)
    @editSession.getCurrentMode().autoOutdent(state, new AceOutdentAdaptor(@editSession), bufferRow)

  handleBufferChange: (e) ->
    @modifyScreenRange =>
      @anchor?.handleBufferChange(e)
      @cursor.handleBufferChange(e)

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
    newScreenRange = @getScreenRange()
    @trigger 'change-screen-range', newScreenRange unless oldScreenRange.isEqual(newScreenRange)

  placeAnchor: ->
    @anchor = new Anchor(@editSession)
    @anchor.setScreenPosition(@cursor.getScreenPosition())

  intersectsBufferRange: (bufferRange) ->
    @getBufferRange().intersectsWith(bufferRange)

  intersectsWith: (otherSelection) ->
    @getScreenRange().intersectsWith(otherSelection.getScreenRange())

  merge: (otherSelection, options) ->
    @setScreenRange(@getScreenRange().union(otherSelection.getScreenRange()), options)
    otherSelection.destroy()

_.extend Selection.prototype, EventEmitter
