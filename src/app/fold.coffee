Range = require 'range'
Point = require 'point'

# Public: Represents a fold that's hiding text from the screen. 
#
# Folds are the primary reason that screen ranges and buffer ranges vary. Their
# creation is managed by the {DisplayBuffer}.
module.exports =
class Fold
  @idCounter: 1

  displayBuffer: null
  startRow: null
  endRow: null

  ### Internal ###

  constructor: (@displayBuffer, @startRow, @endRow) ->
    @id = @constructor.idCounter++

  destroy: ->
    @displayBuffer.destroyFold(this)

  inspect: ->
    "Fold(#{@startRow}, #{@endRow})"

  # Retrieves the buffer row range that a fold occupies.
  #
  # includeNewline - A {Boolean} which, if `true`, includes the trailing newline
  #
  # Returns a {Range}.
  getBufferRange: ({includeNewline}={}) ->
    if includeNewline
      end = [@endRow + 1, 0]
    else
      end = [@endRow, Infinity]

    new Range([@startRow, 0], end)

  # Retrieves the number of buffer rows a fold occupies.
  #
  # Returns a {Number}.
  getBufferRowCount: ->
    @endRow - @startRow + 1

  handleBufferChange: (event) ->
    oldStartRow = @startRow

    if @isContainedByRange(event.oldRange)
      @displayBuffer.unregisterFold(@startRow, this)
      return

    @startRow += @getRowDelta(event, @startRow)
    @endRow += @getRowDelta(event, @endRow)

    if @startRow != oldStartRow
      @displayBuffer.unregisterFold(oldStartRow, this)
      @displayBuffer.registerFold(this)

  # Identifies if a {Range} occurs within a fold.
  #
  # range - A {Range} to check
  #
  # Returns a {Boolean}.
  isContainedByRange: (range) ->
    range.start.row <= @startRow and @endRow <= range.end.row

  # Identifies if a fold is nested within a fold.
  #
  # fold - A {Fold} to check
  #
  # Returns a {Boolean}.
  isContainedByFold: (fold) ->
    @isContainedByRange(fold.getBufferRange())

  getRowDelta: (event, row) ->
    { newRange, oldRange } = event

    if oldRange.end.row <= row
      newRange.end.row - oldRange.end.row
    else if newRange.end.row < row
      newRange.end.row - row
    else
      0
