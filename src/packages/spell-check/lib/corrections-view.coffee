{$$} = require 'space-pen'
Range = require 'range'
SelectList = require 'select-list'

module.exports =
class CorrectionsView extends SelectList
  @viewClass: -> "corrections #{super} popover-list"

  editor: null
  corrections: null
  misspellingRange: null
  aboveCursor: false

  initialize: (@editor, @corrections, @misspellingRange) ->
    super

    @attach()

  itemForElement: (word) ->
    $$ ->
      @li word

  selectNextItem: ->
    super

    false

  selectPreviousItem: ->
    super

    false

  confirmed: (correction) ->
    @cancel()
    return unless correction
    @editor.transact =>
      @editor.setSelectedBufferRange(@editor.bufferRangeForScreenRange(@misspellingRange))
      @editor.insertText(correction)

  attach: ->
    @aboveCursor = false
    if @corrections.length > 0
      @setArray(@corrections)
    else
      @setError("No corrections found")

    @editor.appendToLinesView(this)
    @setPosition()
    @miniEditor.focus()

  detach: ->
    super

    @editor.focus()

  setPosition: ->
    { left, top } = @editor.pixelPositionForScreenPosition(@misspellingRange.start)
    height = @outerHeight()
    potentialTop = top + @editor.lineHeight
    potentialBottom = potentialTop - @editor.scrollTop() + height

    if @aboveCursor or potentialBottom > @editor.outerHeight()
      @aboveCursor = true
      @css(left: left, top: top - height, bottom: 'inherit')
    else
      @css(left: left, top: potentialTop, bottom: 'inherit')

  populateList: ->
    super

    @setPosition()
