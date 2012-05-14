{View, $$$} = require 'space-pen'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Gutter extends View
  @content: ->
    @div class: 'gutter'

  renderLineNumbers: (startScreenRow, endScreenRow) ->
    editor = @parentView
    lastScreenRow = -1
    rows = editor.bufferRowsForScreenRows(startScreenRow, endScreenRow)

    @css('margin-top', -editor.verticalScrollbar.scrollTop() % editor.lineHeight)

    this[0].innerHTML = $$$ ->
      for row in rows
        @div {class: 'line-number'}, if row == lastScreenRow then '•' else row + 1
        lastScreenRow = row