Cursor = require 'cursor'

Range = require 'range'
{View, $$} = require 'space-pen'

module.exports =
class Selection extends View
  @content: ->
    @div()

  anchor: null
  modifyingSelection: null
  regions: null

  initialize: (@editor) ->
    @regions = []
    @cursor = @editor.cursor
    @cursor.on 'cursor:position-changed', =>
      if @modifyingSelection
        @updateAppearance()
      else
        @clearSelection()

  clearSelection: ->
    @anchor = null
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
    if @anchor
      new Range(@anchor.getScreenPosition(), @cursor.getScreenPosition())
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
    @editor.buffer.change(@getBufferRange(), text)

  delete: ->
    range = @getBufferRange()
    @editor.buffer.change(range, '') unless range.isEmpty()

  isEmpty: ->
    @getBufferRange().isEmpty()

  modifySelection: (fn) ->
    @placeAnchor()
    @modifyingSelection = true
    fn()
    @modifyingSelection = false

  placeAnchor: ->
    return if @anchor
    cursorPosition = @cursor.getScreenPosition()
    @anchor = { getScreenPosition: -> cursorPosition }

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

  selectToBufferPosition: (position) ->
    @modifySelection =>
      @cursor.setBufferPosition(position)

  moveCursorToLineEnd: ->
    @cursor.moveToLineEnd()

  moveCursorToLineStart: ->
    @cursor.moveToLineStart()

  cut: ->
    @copy()
    @delete()

  copy: ->
    return if @isEmpty()
    text = @editor.buffer.getTextInRange(@getBufferRange())
    $native.writeToPasteboard text

  fold: ->
    range = @getBufferRange()
    @editor.createFold(range)
    @cursor.setBufferPosition(range.end)
