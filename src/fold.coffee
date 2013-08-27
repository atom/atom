{Point, Range} = require 'telepath'

# Private: Represents a fold that collapses multiple buffer lines into a single
# line on the screen.
#
# Their creation is managed by the {DisplayBuffer}.
module.exports =
class Fold
  id: null
  displayBuffer: null
  marker: null

  ### Internal ###

  constructor: (@displayBuffer, @marker) ->
    @id = @marker.id
    @displayBuffer.foldsByMarkerId[@marker.id] = this
    @updateDisplayBuffer()
    @marker.on 'destroyed', => @destroyed()
    @marker.on 'changed', ({isValid}) => @destroy() unless isValid

  # Returns whether this fold is contained within another fold
  isInsideLargerFold: ->
    if largestContainingFoldMarker = @displayBuffer.findMarker(class: 'fold', containsBufferRange: @getBufferRange())
      not largestContainingFoldMarker.getBufferRange().isEqual(@getBufferRange())
    else
      false

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
    if includeNewline
      range.end.row++
      range.end.column = 0
    range

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
