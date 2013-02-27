{View} = require 'space-pen'
Range = require 'range'

module.exports =
class MisspellingView extends View
  @content: ->
    @div class: 'misspelling'

  initialize: (range, @editor) ->
    @editSession = @editor.activeEditSession
    range = @editSession.screenRangeForBufferRange(Range.fromObject(range))
    @startPosition = range.start
    @endPosition = range.end

    @marker = @editSession.markScreenRange(range, invalidationStrategy: 'between')
    @editSession.observeMarker @marker, ({newHeadScreenPosition, newTailScreenPosition, valid}) =>
      @startPosition = newTailScreenPosition
      @endPosition = newHeadScreenPosition
      @updateDisplayPosition = valid
      @hide() unless valid

    @editor.on 'editor:display-updated', =>
      @updatePosition() if @updateDisplayPosition

    @updatePosition()

  updatePosition: ->
    @updateDisplayPosition = false
    startPixelPosition = @editor.pixelPositionForScreenPosition(@startPosition)
    endPixelPosition = @editor.pixelPositionForScreenPosition(@endPosition)
    @css
      top: startPixelPosition.top
      left: startPixelPosition.left
      width: endPixelPosition.left - startPixelPosition.left
      height: @editor.lineHeight
    @show()

  destroy: ->
    @editSession.destroyMarker(@marker)
    @remove()
