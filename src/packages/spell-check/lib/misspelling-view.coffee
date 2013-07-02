{View} = require 'space-pen'
{Range} = require 'telepath'
CorrectionsView = require './corrections-view'

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
    @marker.on 'changed', ({newHeadScreenPosition, newTailScreenPosition, valid}) =>
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
      SpellChecker = require 'spellchecker'
      corrections = SpellChecker.getCorrectionsForMisspelling(misspelling)
      @correctionsView?.remove()
      @correctionsView = new CorrectionsView(@editor, corrections, screenRange)

    @updatePosition()

  getScreenRange: ->
    new Range(@startPosition, @endPosition)

  unsubscribe: ->
    super
    @marker.destroy()

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
