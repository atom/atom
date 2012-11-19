{View, $$, $$$} = require 'space-pen'

$ = require 'jquery'
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
    highlightCursorLine = => @highlightCursorLine()
    editor.on 'cursor-move', highlightCursorLine
    editor.on 'selection-change', highlightCursorLine
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
    @highlightedRow = null
    @highlightCursorLine()

  calculateWidth: ->
    highestNumberWidth = @editor().getLineCount().toString().length * @editor().charWidth
    if highestNumberWidth != @highestNumberWidth
      @highestNumberWidth = highestNumberWidth
      @lineNumbers.width(highestNumberWidth + @calculateLineNumberPadding())
      @widthChanged?(@outerWidth())

  highlightCursorLine: ->
    if @editor().getSelection().isEmpty()
      rowToHighlight = @editor().getCursorScreenPosition().row
      return if rowToHighlight == @highlightedRow
      return if rowToHighlight < @firstScreenRow or rowToHighlight > @lastScreenRow

      @highlightedLineNumber?.classList.remove('cursor-line')
      if @highlightedLineNumber = @lineNumbers[0].children[rowToHighlight - @firstScreenRow]
        @highlightedLineNumber.classList.add('cursor-line')
        @highlightedRow = rowToHighlight
    else
      @highlightedLineNumber?.classList.remove('cursor-line')
      @highlightedLineNumber = null
      @highlightedRow = null
