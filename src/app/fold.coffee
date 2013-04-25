Range = require 'range'
Point = require 'point'

# Public: Represents a fold that's hiding text from the screen.
#
# Folds are the primary reason that screen ranges and buffer ranges vary. Their
# creation is managed by the {DisplayBuffer}.
module.exports =
class Fold
  displayBuffer: null
  marker: null

  constructor: (@displayBuffer, @marker) ->
    @displayBuffer.foldsByMarkerId[@marker.id] = this
    @updateDisplayBuffer()
    @marker.on 'changed', (e) =>
      oldRange = new Range(e.oldHeadBufferPosition, e.oldTailBufferPosition)
      newRange = new Range(e.newHeadBufferPosition, e.newTailBufferPosition)
      @updateDisplayBuffer() unless newRange.isEqual(oldRange)
    @marker.on 'destroyed', => @destroyed()

  updateDisplayBuffer: ->
    unless @isInsideLargerFold()
      @displayBuffer.updateScreenLines(@getStartRow(), @getEndRow(), 0, updateMarkers: true)

  isInsideLargerFold: ->
    @displayBuffer.findMarker(class: 'fold', containsBufferRange: @getBufferRange())?

  destroy: ->
    @marker.destroy()

  getBufferRange: ->
    @marker.getBufferRange()

  getStartRow: ->
    @getBufferRange().start.row

  getEndRow: ->
    @getBufferRange().end.row

  inspect: ->
    "Fold(#{@getStartRow()}, #{@getEndRow()})"

  # Retrieves the number of buffer rows spanned by the fold.
  #
  # Returns a {Number}.
  getBufferRowCount: ->
    @getEndRow() - @getStartRow() + 1

  ## Internal ##

  destroyed: ->
    delete @displayBuffer.foldsByMarkerId[@marker.id]
    @updateDisplayBuffer()
