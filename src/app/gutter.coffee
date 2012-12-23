{View, $$, $$$} = require 'space-pen'

$ = require 'jquery'
_ = require 'underscore'
Range = require 'range'

module.exports =
class Gutter extends View
  @content: ->
    @div class: 'gutter', =>
      @div outlet: 'lineNumbers', class: 'line-numbers'

  firstScreenRow: Infinity
  lastScreenRow: -1
  highestNumberWidth: null

  afterAttach: (onDom) ->
    return if @attached or not onDom
    @attached = true

    editor = @editor()
    highlightLines = => @highlightLines()
    editor.on 'cursor-move', highlightLines
    editor.on 'selection-change', highlightLines
    @calculateWidth()

  editor: ->
    @parentView

  calculateLineNumberPadding: ->
    widthTesterElement = $$ -> @div {class: 'line-number'}, ""
    widthTesterElement.width(0)
    @append(widthTesterElement)
    lineNumberPadding = widthTesterElement.outerWidth()
    widthTesterElement.remove()
    lineNumberPadding

  updateLineNumbers: (changes, renderFrom, renderTo) ->
    if renderFrom < @firstScreenRow or renderTo > @lastScreenRow
      performUpdate = true
    else if @editor().getLastScreenRow() < @lastScreenRow
      performUpdate = true
    else
      for change in changes
        if change.delta != 0 or (change.bufferDelta? and change.bufferDelta != 0)
          performUpdate = true
          break

    @renderLineNumbers(renderFrom, renderTo) if performUpdate

  renderLineNumbers: (startScreenRow, endScreenRow) ->
    rows = @editor().bufferRowsForScreenRows(startScreenRow, endScreenRow)

    cursorScreenRow = @editor().getCursorScreenPosition().row
    @lineNumbers[0].innerHTML = $$$ ->
      for row in rows
        if row == lastScreenRow
          rowValue = '•'
        else
          rowValue = row + 1
        @div {class: 'line-number'}, rowValue
        lastScreenRow = row

    @calculateWidth()
    @firstScreenRow = startScreenRow
    @lastScreenRow = endScreenRow
    @highlightedRows = null
    @highlightLines()

  calculateWidth: ->
    highestNumberWidth = @editor().getLineCount().toString().length * @editor().charWidth
    if highestNumberWidth != @highestNumberWidth
      @highestNumberWidth = highestNumberWidth
      @lineNumbers.width(highestNumberWidth + @calculateLineNumberPadding())
      @widthChanged?(@outerWidth())

  removeLineHighlights: ->
    return unless @highlightedLineNumbers
    for line in @highlightedLineNumbers
      line.classList.remove('cursor-line')
      line.classList.remove('cursor-line-no-selection')
    @highlightedLineNumbers = null

  addLineHighlight: (row, emptySelection) ->
    return if row < @firstScreenRow or row > @lastScreenRow
    @highlightedLineNumbers ?= []
    if highlightedLineNumber = @lineNumbers[0].children[row - @firstScreenRow]
      highlightedLineNumber.classList.add('cursor-line')
      highlightedLineNumber.classList.add('cursor-line-no-selection') if emptySelection
      @highlightedLineNumbers.push(highlightedLineNumber)

  highlightLines: ->
    if @editor().getSelection().isEmpty()
      row = @editor().getCursorScreenPosition().row
      rowRange = new Range([row, 0], [row, 0])
      return if @highlightedRows?.isEqual(rowRange) and @selectionEmpty

      @removeLineHighlights()
      @addLineHighlight(row, true)
      @highlightedRows = rowRange
      @selectionEmpty = true
    else
      selectedRows = @editor().getSelection().getScreenRange()
      selectedRows = new Range([selectedRows.start.row, 0], [selectedRows.end.row, 0])
      return if @highlightedRows?.isEqual(selectedRows) and not @selectionEmpty

      @removeLineHighlights()
      for row in [selectedRows.start.row..selectedRows.end.row]
        @addLineHighlight(row, false)
      @highlightedRows = selectedRows
      @selectionEmpty = false
