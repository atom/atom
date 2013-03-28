{View, $$, $$$} = require 'space-pen'
Range = require 'range'
_ = require 'underscore'

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
    editor.on 'cursor:moved', highlightLines
    editor.on 'selection:changed', highlightLines

  editor: ->
    @parentView

  setShowLineNumbers: (showLineNumbers) ->
    if showLineNumbers then @lineNumbers.show() else @lineNumbers.hide()

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
    editor = @editor()
    maxDigits = editor.getLineCount().toString().length
    rows = editor.bufferRowsForScreenRows(startScreenRow, endScreenRow)

    cursorScreenRow = editor.getCursorScreenPosition().row
    @lineNumbers[0].innerHTML = $$$ ->
      for row in rows
        if row == lastScreenRow
          rowValue = '•'
        else
          rowValue = (row + 1).toString()
        classes = ['line-number']
        classes.push('fold') if editor.isFoldedAtBufferRow(row)
        @div class: classes.join(' '), =>
          rowValuePadding = _.multiplyString('&nbsp;', maxDigits - rowValue.length)
          @raw("#{rowValuePadding}#{rowValue}")

        lastScreenRow = row

    @firstScreenRow = startScreenRow
    @lastScreenRow = endScreenRow
    @highlightedRows = null
    @highlightLines()

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
      return if @selectionEmpty and @highlightedRows?.isEqual(rowRange)

      @removeLineHighlights()
      @addLineHighlight(row, true)
      @highlightedRows = rowRange
      @selectionEmpty = true
    else
      selectedRows = @editor().getSelection().getScreenRange()
      endRow = selectedRows.end.row
      endRow-- if selectedRows.end.column is 0
      selectedRows = new Range([selectedRows.start.row, 0], [endRow, 0])
      return if not @selectionEmpty and @highlightedRows?.isEqual(selectedRows)

      @removeLineHighlights()
      for row in [selectedRows.start.row..selectedRows.end.row]
        @addLineHighlight(row, false)
      @highlightedRows = selectedRows
      @selectionEmpty = false
