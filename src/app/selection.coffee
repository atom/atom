Anchor = require 'anchor'
AceOutdentAdaptor = require 'ace-outdent-adaptor'
Point = require 'point'
Range = require 'range'
{View, $$} = require 'space-pen'

module.exports =
class Selection extends View
  @content: ->
    @div()

  anchor: null
  retainSelection: null
  regions: null

  initialize: ({@editor, @cursor} = {}) ->
    @regions = []

  handleBufferChange: (e) ->
    return unless @anchor
    @anchor.handleBufferChange(e)
    @updateAppearance()

  placeAnchor: ->
    return if @anchor
    @anchor = new Anchor(@editor)
    @anchor.setScreenPosition @cursor.getScreenPosition()

  isEmpty: ->
    @getBufferRange().isEmpty()

  isReversed: ->
    not @isEmpty() and @cursor.getBufferPosition().isLessThan(@anchor.getBufferPosition())

  intersectsWith: (otherSelection) ->
    @getScreenRange().intersectsWith(otherSelection.getScreenRange())

  clearSelection: ->
    @anchor = null
    @updateAppearance()

  updateAppearance: ->
    return unless @cursor

    @clearRegions()

    range = @getScreenRange()

    @editor.highlightSelectedFolds()
    return if range.isEmpty()

    rowSpan = range.end.row - range.start.row

    if rowSpan == 0
      @appendRegion(1, range.start, range.end)
    else
      @appendRegion(1, range.start, null)
      if rowSpan > 1
        @appendRegion(rowSpan - 1, { row: range.start.row + 1, column: 0}, null)
      @appendRegion(1, { row: range.end.row, column: 0 }, range.end)


  appendRegion: (rows, start, end) ->
    { lineHeight, charWidth } = @editor
    css = @editor.pixelPositionForScreenPosition(start)
    css.height = lineHeight * rows
    if end
      css.width = @editor.pixelPositionForScreenPosition(end).left - css.left
    else
      css.right = 0

    region = ($$ -> @div class: 'selection').css(css)
    @append(region)
    @regions.push(region)

  clearRegions: ->
    region.remove() for region in @regions
    @regions = []

  getScreenRange: ->
    if @anchor
      new Range(@anchor.getScreenPosition(), @cursor.getScreenPosition())
    else
      new Range(@cursor.getScreenPosition(), @cursor.getScreenPosition())

  setScreenRange: (range, {reverse}={}) ->
    range = Range.fromObject(range)
    { start, end } = range
    [start, end] = [end, start] if reverse

    @cursor.setScreenPosition(start)
    @modifySelection => @cursor.setScreenPosition(end)

  getBufferRange: ->
    @editor.bufferRangeForScreenRange(@getScreenRange())

  setBufferRange: (bufferRange, options) ->
    @setScreenRange(@editor.screenRangeForBufferRange(bufferRange), options)

  getText: ->
    @editor.buffer.getTextInRange @getBufferRange()

  intersectsBufferRange: (bufferRange) ->
    @getBufferRange().intersectsWith(bufferRange)

  insertText: (text) ->
    { text, shouldOutdent } = @autoIndentText(text)
    oldBufferRange = @getBufferRange()
    @editor.destroyFoldsContainingBufferRow(oldBufferRange.end.row)
    wasReversed = @isReversed()
    @clearSelection()
    newBufferRange = @editor.buffer.change(oldBufferRange, text)
    @cursor.setBufferPosition(newBufferRange.end, skipAtomicTokens: true) if wasReversed
    @autoOutdentText() if shouldOutdent

  indentSelectedRows: ->
    range = @getBufferRange()
    for row in [range.start.row..range.end.row]
      @editor.buffer.insert([row, 0], @editor.tabText) unless @editor.buffer.lineLengthForRow(row) == 0

  outdentSelectedRows: ->
    range = @getBufferRange()
    buffer = @editor.buffer
    leadingTabRegex = new RegExp("^#{@editor.tabText}")
    for row in [range.start.row..range.end.row]
      if leadingTabRegex.test buffer.lineForRow(row)
        buffer.delete [[row, 0], [row, @editor.tabText.length]]

  toggleLineComments: ->
    @modifySelection =>
      @editor.toggleLineCommentsInRange(@getBufferRange())

  autoIndentText: (text) ->
    if @editor.autoIndent
      mode = @editor.getCurrentMode()
      row = @cursor.getScreenPosition().row
      state = @editor.stateForScreenRow(row)
      lineBeforeCursor = @cursor.getCurrentBufferLine()[0...@cursor.getBufferPosition().column]
      if text[0] == "\n"
        indent = mode.getNextLineIndent(state, lineBeforeCursor, @editor.tabText)
        text = text[0] + indent + text[1..]
      else if mode.checkOutdent(state, lineBeforeCursor, text)
        shouldOutdent = true

    {text, shouldOutdent}

  autoOutdentText: ->
    screenRow = @cursor.getScreenPosition().row
    bufferRow = @cursor.getBufferPosition().row
    state = @editor.renderer.lineForRow(screenRow).state
    @editor.getCurrentMode().autoOutdent(state, new AceOutdentAdaptor(@editor.buffer, @editor), bufferRow)

  backspace: ->
    @editor.destroyFoldsContainingBufferRow(@getBufferRange().end.row)
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
    range = @getBufferRange()
    @editor.buffer.delete(range) unless range.isEmpty()
    @clearSelection()

  merge: (otherSelection, options) ->
    @setScreenRange(@getScreenRange().union(otherSelection.getScreenRange()), options)
    otherSelection.remove()

  remove: ->
    @cursor?.remove()
    super

  modifySelection: (fn) ->
    @placeAnchor()
    @retainSelection = true
    fn()
    @retainSelection = false

  selectWord: ->
    @setBufferRange(@cursor.getCurrentWordBufferRange())

  expandOverWord: ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentWordBufferRange()))

  selectLine: (row=@cursor.getBufferPosition().row) ->
    @setBufferRange(@editor.rangeForBufferRow(row))

  expandOverLine: ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentLineBufferRange()))

  selectToScreenPosition: (position) ->
    @modifySelection => @cursor.setScreenPosition(position)

  selectRight: ->
    @modifySelection => @cursor.cursor.moveRight()

  selectLeft: ->
    @modifySelection => @cursor.cursor.moveLeft()

  selectUp: ->
    @modifySelection => @cursor.cursor.moveUp()

  selectDown: ->
    @modifySelection => @cursor.cursor.moveDown()

  selectToTop: ->
    @modifySelection => @cursor.cursor.moveToTop()

  selectToBottom: ->
    @modifySelection => @cursor.cursor.moveToBottom()

  selectAll: ->
    @setBufferRange(@editor.buffer.getRange())

  selectToBeginningOfLine: ->
    @modifySelection => @cursor.cursor.moveToBeginningOfLine()

  selectToEndOfLine: ->
    @modifySelection => @cursor.cursor.moveToEndOfLine()

  selectToBeginningOfWord: ->
    @modifySelection => @cursor.moveToBeginningOfWord()

  selectToEndOfWord: ->
    @modifySelection => @cursor.moveToEndOfWord()

  cutToEndOfLine: (maintainPasteboard) ->
    @selectToEndOfLine() if @isEmpty()
    @cut(maintainPasteboard)

  cut: (maintainPasteboard=false) ->
    @copy(maintainPasteboard)
    @delete()

  copy: (maintainPasteboard=false) ->
    return if @isEmpty()
    text = @editor.buffer.getTextInRange(@getBufferRange())
    text = $native.readFromPasteboard() + "\n" + text if maintainPasteboard
    $native.writeToPasteboard text

  fold: ->
    range = @getBufferRange()
    @editor.createFold(range.start.row, range.end.row)
    @cursor.setBufferPosition([range.end.row + 1, 0])
