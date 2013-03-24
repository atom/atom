{View} = require 'space-pen'
Range = require 'range'
CorrectionsView = require './corrections-view'
NSSpellChecker = require 'nsspellchecker'

module.exports =
class MisspellingView extends View
  @content: ->
    @div class: 'misspelling'

  initialize: (range, @editor) ->
    @editSession = @editor.activeEditSession
    range = @editSession.screenRangeForBufferRange(Range.fromObject(range))
    @startPosition = range.start
    @endPosition = range.end
    @misspellingValid = true

    @marker = @editSession.markScreenRange(range, invalidationStrategy: 'between')
    @editSession.observeMarker @marker, ({newHeadScreenPosition, newTailScreenPosition, valid}) =>
      @startPosition = newTailScreenPosition
      @endPosition = newHeadScreenPosition
      @updateDisplayPosition = valid
      @misspellingValid = valid
      @hide() unless valid

    @subscribe @editor, 'editor:display-updated', =>
      @updatePosition() if @updateDisplayPosition

    @editor.command 'editor:correct-misspelling', =>
      return unless @misspellingValid and @containsCursor()

      screenRange = @getScreenRange()
      misspelling = @editor.getTextInRange(@editor.bufferRangeForScreenRange(screenRange))
      corrections = NSSpellChecker.getCorrectionsForMisspelling(misspelling)
      @correctionsView?.remove()
      @correctionsView = new CorrectionsView(@editor, corrections, screenRange)

    @updatePosition()

  getScreenRange: ->
    new Range(@startPosition, @endPosition)

  unsubscribe: ->
    super

    @editSession.destroyMarker(@marker)

  containsCursor: ->
    cursor = @editor.getCursorScreenPosition()
    @getScreenRange().containsPoint(cursor, exclusive: false)

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
    @misspellingValid = false
    @editSession.destroyMarker(@marker)
    @correctionsView?.remove()
    @remove()
