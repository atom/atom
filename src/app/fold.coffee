Range = require 'range'
Point = require 'point'

# Public: Represents a fold that collapses multiple buffer lines into a single
# line on the screen.
#
# Their creation is managed by the {DisplayBuffer}.
module.exports =
class Fold
  displayBuffer: null
  marker: null

  # Internal
  constructor: (@displayBuffer, @marker) ->
    @displayBuffer.foldsByMarkerId[@marker.id] = this
    @updateDisplayBuffer()
    @marker.on 'destroyed', => @destroyed()

  # Returns whether this fold is contained within another fold
  isInsideLargerFold: ->
    @displayBuffer.findMarker(class: 'fold', containsBufferRange: @getBufferRange())?

  # Destroys this fold
  destroy: ->
    @marker.destroy()

  # Returns the fold's {Range} in buffer coordinates
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

  ## Internal ##

  updateDisplayBuffer: ->
    unless @isInsideLargerFold()
      @displayBuffer.updateScreenLines(@getStartRow(), @getEndRow(), 0, updateMarkers: true)

  destroyed: ->
    delete @displayBuffer.foldsByMarkerId[@marker.id]
    @updateDisplayBuffer()
