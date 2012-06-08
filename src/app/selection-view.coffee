Anchor = require 'anchor'
AceOutdentAdaptor = require 'ace-outdent-adaptor'
Point = require 'point'
Range = require 'range'
{View, $$} = require 'space-pen'

module.exports =
class SelectionView extends View
  @content: ->
    @div()

  anchor: null
  retainSelection: null
  regions: null

  initialize: ({@editor, @selection} = {}) ->
    @cursor = @selection.cursor
    @regions = []
    @selection.view = this
    @selection.on 'change-screen-range', =>
      @updateAppearance()

    @selection.on 'destroy', =>
      @selection = null
      @remove()

  handleBufferChange: (e) ->
    return unless @anchor
    @anchor.handleBufferChange(e)
    @updateAppearance()

  placeAnchor: ->
    return if @anchor
    @anchor = new Anchor(@editor)
    @anchor.setScreenPosition @cursor.getScreenPosition()

  isEmpty: ->
    @selection.isEmpty()

  isReversed: ->
    @selection.isReversed()

  clearSelection: ->
    @selection?.clear()

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
    @selection.getScreenRange()

  setScreenRange: (range, options)->
    @selection.setScreenRange(range, options)

  getBufferRange: ->
    @selection.getBufferRange()

  setBufferRange: (bufferRange, options) ->
    @setScreenRange(@editor.screenRangeForBufferRange(bufferRange), options)

  getText: ->
    @editor.buffer.getTextInRange @getBufferRange()

  intersectsBufferRange: (bufferRange) ->
    @getBufferRange().intersectsWith(bufferRange)

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

  remove: ->
    @editor.compositeSelection.removeSelectionView(this)
    @selection?.destroy()
    super

  modifySelection: (fn) ->
    @selection.modifySelection(fn)

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
    @setBufferRange(@editor.buffer.getRange())

  selectToBeginningOfLine: ->
    @modifySelection => @cursor.moveToBeginningOfLine()

  selectToEndOfLine: ->
    @modifySelection => @cursor.moveToEndOfLine()

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
