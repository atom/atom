{View, $$, $$$} = require 'space-pen'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Gutter extends View
  @content: ->
    @div class: 'gutter', =>
      @div outlet: 'lineNumbers', class: 'line-numbers'

  firstScreenRow: -1
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

  renderLineNumbers: (startScreenRow, endScreenRow) ->
    @firstScreenRow = startScreenRow
    lastScreenRow = -1
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
    @highlightCursorLine()

  calculateWidth: ->
    highestNumberWidth = @editor().getLineCount().toString().length * @editor().charWidth
    if highestNumberWidth != @highestNumberWidth
      @highestNumberWidth = highestNumberWidth
      @lineNumbers.width(highestNumberWidth + @calculateLineNumberPadding())
      @widthChanged?(@outerWidth())

  highlightCursorLine: ->
    currentRow = @editor().getCursorScreenPosition().row
    return if @highlightedRow == currentRow

    screenRowIndex = currentRow - @firstScreenRow
    @highlightedLineNumber?.classList.remove('cursor-line')

    if screenRowIndex >= 0 and @editor().getSelection().isSingleScreenLine()
      @highlightedLineNumber = @lineNumbers[0].children[screenRowIndex]
      @highlightedLineNumber?.classList.add('cursor-line')
      @highlightedRow = currentRow
    else
      @highlightedLineNumber = null
      @highlightedRow = null
