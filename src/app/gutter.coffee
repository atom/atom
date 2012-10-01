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
    editor.on 'editor-selection-change', highlightCursorLine
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
        rowClass = 'line-number'
        rowValue = null

        if row == lastScreenRow
          rowValue = '•'
        else
          rowValue = row + 1
          rowClass += ' cursor-line-number' if row == cursorScreenRow

        @div {class: rowClass}, rowValue
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
    cursorScreenRow = @editor().getCursorScreenPosition().row
    screenRowIndex = cursorScreenRow - @firstScreenRow

    currentLineNumberRow = @find(".line-number.cursor-line-number")
    currentLineNumberRow.removeClass('cursor-line-number')
    currentLineNumberRow.removeClass('cursor-line-number-background')

    newLineNumberRow = @find(".line-number:eq(#{screenRowIndex})")
    newLineNumberRow.addClass('cursor-line-number')
    if @editor().getSelection().isSingleScreenLine()
      newLineNumberRow.addClass('cursor-line-number-background')
