{View, $$$} = require 'space-pen'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Gutter extends View
  @content: ->
    @div class: 'gutter', =>
      @div outlet: 'lineNumbers', class: 'wtf'

  renderLineNumbers: (startScreenRow, endScreenRow) ->
    editor = @parentView
    lastScreenRow = -1
    rows = editor.bufferRowsForScreenRows(startScreenRow, endScreenRow)

    @lineNumbers[0].innerHTML = $$$ ->
      for row in rows
        @div {class: 'line-number'}, if row == lastScreenRow then '•' else row + 1
        lastScreenRow = row

    @lineNumbers.width(editor.buffer.getLastRow().toString().length * editor.charWidth)
