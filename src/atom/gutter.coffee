{View, $$} = require 'space-pen'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Gutter extends View
  @content: ->
    @div class: 'gutter'

  renderLineNumbers: ->
    @empty()

    lastRow = -1
    for row in @parentView.bufferRowsForScreenRows()
      @append $$ ->
        @div {class: 'line-number'}, if row == lastRow then '•' else row + 1
      lastRow = row
