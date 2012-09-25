{View, $$$} = require 'space-pen'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Gutter extends View
  @content: ->
    @div class: 'gutter', =>
      @div outlet: 'lineNumbers', class: 'line-numbers'

  editor: ->
    @parentView

  renderLineNumbers: (startScreenRow, endScreenRow) ->
    lastScreenRow = -1
    rows = @editor().bufferRowsForScreenRows(startScreenRow, endScreenRow)

    @lineNumbers[0].innerHTML = $$$ ->
      for row in rows
        @div {class: 'line-number'}, if row == lastScreenRow then '•' else row + 1
        lastScreenRow = row

    @calculateWidth()

  calculateWidth: ->
    width = @editor().getLineCount().toString().length * @editor().charWidth
    if width != @cachedWidth
      @cachedWidth = width
      @lineNumbers.width(width)
      @widthChanged?(@outerWidth())
