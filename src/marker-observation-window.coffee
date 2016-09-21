module.exports =
class MarkerObservationWindow
  constructor: (@decorationManager, @bufferWindow) ->

  setScreenRange: (range) ->
    @bufferWindow.setRange(@decorationManager.bufferRangeForScreenRange(range))

  setBufferRange: (range) ->
    @bufferWindow.setRange(range)

  destroy: ->
    @bufferWindow.destroy()
