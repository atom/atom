module.exports =
class MarkerObservationWindow
  constructor: (@displayBuffer, @bufferWindow) ->

  setScreenRange: (range) ->
    @bufferWindow.setRange(@displayBuffer.bufferRangeForScreenRange(range))

  setBufferRange: (range) ->
    @bufferWindow.setRange(range)

  destroy: ->
    @bufferWindow.destroy()
