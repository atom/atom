{View, $$$} = require 'space-pen'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Gutter extends View
  @content: ->
    @div class: 'gutter', =>
      @div outlet: 'lineNumbers', class: 'line-numbers'

  cursorBufferRow: -1
  firstScreenRow: -1

  afterAttach: (onDom) ->
    @editor()?.on 'cursor-move', => @highlightCursorLine()

  editor: ->
    @parentView

  renderLineNumbers: (startScreenRow, endScreenRow) ->
    @firstScreenRow = startScreenRow
    lastScreenRow = -1
    currentCursorBufferRow = @cursorBufferRow
    rows = @editor().bufferRowsForScreenRows(startScreenRow, endScreenRow)

    @lineNumbers[0].innerHTML = $$$ ->
      for row in rows
        rowClass = null
        if row isnt currentCursorBufferRow
          rowClass = 'line-number'
        else
          rowClass = 'line-number cursor-line-number'
        @div {class: rowClass}, if row == lastScreenRow then '•' else row + 1
        lastScreenRow = row

    @calculateWidth()
    @highlightCursorLine()

  calculateWidth: ->
    width = @editor().getLineCount().toString().length * @editor().charWidth
    if width != @cachedWidth
      @cachedWidth = width
      @lineNumbers.width(width)
      @widthChanged?(@outerWidth())

  highlightCursorLine: ->
    return if @firstScreenRow < 0

    newCursorBufferRow = @editor().getCursorBufferPosition().row
    if newCursorBufferRow isnt @cursorBufferRow
      @cursorBufferRow = newCursorBufferRow
      screenRow = @cursorBufferRow - @firstScreenRow
      @find('.line-number.cursor-line-number').removeClass('cursor-line-number')
      @find(".line-number:eq(#{screenRow})").addClass('cursor-line-number')
