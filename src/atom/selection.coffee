Cursor = require 'cursor'
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

  initialize: ({@editor, @cursor}) ->
    @regions = []
    @cursor.on 'cursor:position-changed', =>
      if @retainSelection
        @updateAppearance()
      else
        @clearSelection()

  handleBufferChange: (e) ->
    return unless @anchorScreenPosition

    { oldRange, newRange } = e
    position = @anchorBufferPosition
    return if position.isLessThan(oldRange.end)

    newRow = newRange.end.row
    newColumn = newRange.end.column
    if position.row == oldRange.end.row
      newColumn += position.column - oldRange.end.column
    else
      newColumn = position.column
      newRow += position.row - oldRange.end.row

    @setAnchorBufferPosition([newRow, newColumn])

  clearSelection: ->
    @anchorScreenPosition = null
    @updateAppearance()

  updateAppearance: ->
    @clearRegions()

    range = @getScreenRange()
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
    if @anchorScreenPosition
      new Range(@anchorScreenPosition, @cursor.getScreenPosition())
    else
      new Range(@cursor.getScreenPosition(), @cursor.getScreenPosition())

  setScreenRange: (range) ->
    @cursor.setScreenPosition(range.start)
    @modifySelection =>
      @cursor.setScreenPosition(range.end)

  getBufferRange: ->
    @editor.bufferRangeForScreenRange(@getScreenRange())

  setBufferRange: (bufferRange) ->
    @setScreenRange(@editor.screenRangeForBufferRange(bufferRange))

  getText: ->
    @editor.buffer.getTextInRange @getBufferRange()

  insertText: (text) ->
    { text, shouldOutdent } = @autoIndentText(text)
    @editor.buffer.change(@getBufferRange(), text)
    @autoOutdentText() if shouldOutdent

  autoIndentText: (text) ->
    if @editor.autoIndent
      mode = @editor.getCurrentMode()
      row = @cursor.getScreenPosition().row
      state = @editor.stateForScreenRow(row)
      if text[0] == "\n"
        indent = mode.getNextLineIndent(state, @cursor.getCurrentBufferLine(), atom.tabText)
        text = text[0] + indent + text[1..]
      else if mode.checkOutdent(state, @cursor.getCurrentBufferLine(), text)
        shouldOutdent = true

    {text, shouldOutdent}

  autoOutdentText: ->
    screenRow = @cursor.getScreenPosition().row
    bufferRow = @cursor.getBufferPosition().row
    state = @editor.renderer.lineForRow(screenRow).state
    @editor.getCurrentMode().autoOutdent(state, new AceOutdentAdaptor(@editor.buffer, @editor), bufferRow)

  backspace: ->
    @selectLeft() if @isEmpty()
    @deleteSelectedText()

  delete: ->
    @selectRight() if @isEmpty()
    @deleteSelectedText()

  deleteSelectedText: ->
    range = @getBufferRange()
    @editor.buffer.delete(range) unless range.isEmpty()
    @clearSelection()

  isEmpty: ->
    @getBufferRange().isEmpty()

  intersectsWith: (otherSelection) ->
    @getScreenRange().intersectsWith(otherSelection.getScreenRange())

  merge: (otherSelection) ->
    @setScreenRange(@getScreenRange().union(otherSelection.getScreenRange()))
    otherSelection.remove()

  remove: ->
    @cursor?.remove()
    super

  modifySelection: (fn) ->
    @placeAnchor()
    @retainSelection = true
    fn()
    @retainSelection = false

  placeAnchor: ->
    return if @anchorScreenPosition
    @setAnchorScreenPosition(@cursor.getScreenPosition())

  setAnchorScreenPosition: (screenPosition) ->
    bufferPosition = Point.fromObject(screenPosition)
    @anchorScreenPosition = screenPosition
    @anchorBufferPosition = @editor.bufferPositionForScreenPosition(screenPosition)

  setAnchorBufferPosition: (bufferPosition) ->
    bufferPosition = Point.fromObject(bufferPosition)
    @anchorBufferPosition = bufferPosition
    @anchorScreenPosition = @editor.screenPositionForBufferPosition(bufferPosition)

  selectWord: ->
    row = @cursor.getScreenRow()
    column = @cursor.getScreenColumn()

    { row, column } = @cursor.getBufferPosition()

    line = @editor.buffer.lineForRow(row)
    leftSide = line[0...column].split('').reverse().join('') # reverse left side
    rightSide = line[column..]

    regex = /^\w*/
    startOffset = -regex.exec(leftSide)?[0]?.length or 0
    endOffset = regex.exec(rightSide)?[0]?.length or 0

    range = new Range([row, column + startOffset], [row, column + endOffset])
    @setBufferRange range

  selectLine: (row=@cursor.getBufferPosition().row) ->
    rowLength = @editor.buffer.lineForRow(row).length
    @setBufferRange new Range([row, 0], [row, rowLength])

  selectRight: ->
    @modifySelection =>
      @cursor.moveRight()

  selectLeft: ->
    @modifySelection =>
      @cursor.moveLeft()

  selectUp: ->
    @modifySelection =>
      @cursor.moveUp()

  selectDown: ->
    @modifySelection =>
      @cursor.moveDown()

  selectLeftUntilMatch: (regex) ->
    @modifySelection =>
      @cursor.moveLeftUntilMatch(regex)

  selectToScreenPosition: (position) ->
    @modifySelection =>
      @cursor.setScreenPosition(position)

  moveCursorToLineEnd: ->
    @cursor.moveToLineEnd()

  moveCursorToLineStart: ->
    @cursor.moveToLineStart()

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
    @editor.createFold(range)
    @cursor.setBufferPosition(range.end)
