{Point, Range} = require 'text-buffer'

# Represents a fold that collapses multiple buffer lines into a single
# line on the screen.
#
# Their creation is managed by the {DisplayBuffer}.
module.exports =
class Fold
  id: null
  displayBuffer: null
  marker: null

  constructor: (@displayBuffer, @marker) ->
    @id = @marker.id
    @displayBuffer.foldsByMarkerId[@marker.id] = this
    @marker.onDidDestroy => @destroyed()
    @marker.onDidChange ({isValid}) => @destroy() unless isValid

  # Returns whether this fold is contained within another fold
  isInsideLargerFold: ->
    largestContainingFoldMarker = @displayBuffer.findFoldMarker(containsRange: @getBufferRange())
    largestContainingFoldMarker and
      not largestContainingFoldMarker.getRange().isEqual(@getBufferRange())

  # Destroys this fold
  destroy: ->
    @marker.destroy()

  # Returns the fold's {Range} in buffer coordinates
  #
  # includeNewline - A {Boolean} which, if `true`, includes the trailing newline
  #
  # Returns a {Range}.
  getBufferRange: ({includeNewline}={}) ->
    range = @marker.getRange()

    if range.end.row > range.start.row and nextFold = @displayBuffer.largestFoldStartingAtBufferRow(range.end.row)
      nextRange = nextFold.getBufferRange()
      range = new Range(range.start, nextRange.end)

    if includeNewline
      range = range.copy()
      range.end.row++
      range.end.column = 0
    range

  getBufferRowRange: ->
    {start, end} = @getBufferRange()
    [start.row, end.row]

  # Returns the fold's start row as a {Number}.
  getStartRow: ->
    @getBufferRange().start.row

  # Returns the fold's end row as a {Number}.
  getEndRow: ->
    @getBufferRange().end.row

  # Returns a {String} representation of the fold.
  inspect: ->
    "Fold(#{@getStartRow()}, #{@getEndRow()})"

  # Retrieves the number of buffer rows spanned by the fold.
  #
  # Returns a {Number}.
  getBufferRowCount: ->
    @getEndRow() - @getStartRow() + 1

  # Identifies if a fold is nested within a fold.
  #
  # fold - A {Fold} to check
  #
  # Returns a {Boolean}.
  isContainedByFold: (fold) ->
    @isContainedByRange(fold.getBufferRange())

  updateDisplayBuffer: ->
    unless @isInsideLargerFold()
      @displayBuffer.updateScreenLines(@getStartRow(), @getEndRow() + 1, 0, updateMarkers: true)

  destroyed: ->
    delete @displayBuffer.foldsByMarkerId[@marker.id]
    @updateDisplayBuffer()
