{View} = require 'space-pen'

module.exports =
class OperationView extends View
  @content: ({operation} = {}) ->
    {prefix, suffix, match, range} = operation.preview()
    @li 'data-index': operation.index, class: 'operation', =>
      @span range.start.row + 1, class: 'line-number'
      @span class: 'preview', =>
        @span prefix
        @span match, class: 'match'
        @span suffix
