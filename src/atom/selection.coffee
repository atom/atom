Cursor = require 'cursor'
Range = require 'range'
{View} = require 'space-pen'
$$ = require 'template/builder'

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

    range = @getRange()
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
    css = {}
    css.top = start.row * lineHeight
    css.left = start.column * charWidth
    css.height = lineHeight * rows
    if end
      css.width = end.column * charWidth - css.left
    else
      css.right = 0

    region = $$.div(class: 'selection').css(css)
    @append(region)
    @regions.push(region)

  clearRegions: ->
    region.remove() for region in @regions
    @regions = []

  getRange: ->
    if @anchor
      new Range(@anchor.getPosition(), @cursor.getPosition())
    else
      new Range(@cursor.getPosition(), @cursor.getPosition())

  setRange: (range) ->
    @cursor.setPosition(range.start)
    @modifySelection =>
      @cursor.setPosition(range.end)

  getText: ->
    @editor.buffer.getTextInRange @getRange()

  insertText: (text) ->
    @editor.buffer.change(@getRange(), text)

  insertNewline: ->
    @insertText('\n')

  delete: ->
    range = @getRange()
    @editor.buffer.change(range, '') unless range.isEmpty()

  isEmpty: ->
    @getRange().isEmpty()

  modifySelection: (fn) ->
    @placeAnchor()
    @modifyingSelection = true
    fn()
    @modifyingSelection = false

  placeAnchor: ->
    return if @anchor
    cursorPosition = @cursor.getPosition()
    @anchor = { getPosition: -> cursorPosition }

  selectWord: ->
    row = @cursor.getRow()
    column = @cursor.getColumn()

    line = @editor.buffer.getLine(row)
    leftSide = line[0...column].split('').reverse().join('') # reverse left side
    rightSide = line[column..]

    regex = /^\w*/
    startOffset = -regex.exec(leftSide)?[0]?.length or 0
    endOffset = regex.exec(rightSide)?[0]?.length or 0

    range = new Range([row, column + startOffset], [row, column + endOffset])
    @setRange range

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

  selectToPosition: (position) ->
    @modifySelection =>
      @cursor.setPosition(position)

  moveCursorToLineEnd: ->
    @cursor.moveToLineEnd()

  moveCursorToLineStart: ->
    @cursor.moveToLineStart()

  cut: ->
    @copy()
    @delete()

  copy: ->
    return if @isEmpty()
    text = @editor.buffer.getTextInRange @getRange()
    atom.native.writeToPasteboard text
