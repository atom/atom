Anchor = require 'anchor'
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
    @cursor.on 'cursor:position-changed', => @updateAppearance()

  handleBufferChange: (e) ->
    return unless @anchor
    @anchor.handleBufferChange(e)

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

  setScreenRange: (range, options={}) ->
    { reverse } = options
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

  insertText: (text) ->
    { text, shouldOutdent } = @autoIndentText(text)
    @editor.buffer.change(@getBufferRange(), text)
    @autoOutdentText() if shouldOutdent
    @clearSelection()

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
    row = @cursor.getScreenPosition().row
    column = @cursor.getScreenPosition().column

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

  selectToBeginningOfLine: ->
    @modifySelection => @cursor.moveToBeginningOfLine()

  selectToEndOfLine: ->
    @modifySelection => @cursor.moveToEndOfLine()

  selectToBeginningOfWord: ->
    @modifySelection => @cursor.moveToBeginningOfWord()

  selectToEndOfWord: ->
    @modifySelection => @cursor.moveToEndOfWord()

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
