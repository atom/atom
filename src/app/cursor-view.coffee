{View} = require 'space-pen'
Anchor = require 'anchor'
Point = require 'point'
Range = require 'range'
_ = require 'underscore'

module.exports =
class CursorView extends View
  @content: ->
    @pre class: 'cursor idle', => @raw '&nbsp;'

  blinkPeriod: 800
  editor: null
  visible: true

  needsUpdate: true
  needsAutoscroll: true
  needsRemoval: false
  shouldPauseBlinking: false

  initialize: (@cursor, @editor) ->
    @cursor.on 'change-screen-position.cursor-view', (screenPosition, { autoscroll }) =>
      @needsUpdate = true
      @shouldPauseBlinking = true
      @needsAutoscroll = (autoscroll ? true) and @cursor?.isLastCursor()
      @editor.requestDisplayUpdate()

    @cursor.on 'change-visibility.cursor-view', (visible) =>
      @needsUpdate = true
      @needsAutoscroll = visible and @cursor.isLastCursor()
      @editor.requestDisplayUpdate()

    @cursor.on 'destroy.cursor-view', =>
      @needsRemoval = true
      @editor.requestDisplayUpdate()

  remove: ->
    @editor.removeCursorView(this)
    @cursor.off('.cursor-view')
    super

  updateDisplay: ->
    screenPosition = @getScreenPosition()
    pixelPosition = @getPixelPosition()

    unless _.isEqual(@lastPixelPosition, pixelPosition)
      changedPosition = true
      @css(pixelPosition)
      @trigger 'cursor-move'

    if @shouldPauseBlinking
      @resetBlinking()
    else if !@startBlinkingTimeout
      @startBlinking()

    @setVisible(@cursor.isVisible() and not @editor.isFoldedAtScreenRow(screenPosition.row))

  getPixelPosition: ->
    @editor.pixelPositionForScreenPosition(@getScreenPosition())

  setVisible: (visible) ->
    unless @visible == visible
      @visible = visible
      if @visible
        @css('visibility', '')
      else
        @css('visibility', 'hidden')

  toggleVisible: ->
    @setVisible(not @visible)

  stopBlinking: ->
    clearInterval(@blinkInterval) if @blinkInterval
    @blinkInterval = null
    @setVisible(@cursor.isVisible())

  startBlinking: ->
    return if @blinkInterval?
    blink = => @toggleVisible() if @cursor.isVisible()
    @blinkInterval = setInterval(blink, @blinkPeriod / 2)

  resetBlinking: ->
    @stopBlinking()
    @startBlinking()

  getBufferPosition: ->
    @cursor.getBufferPosition()

  getScreenPosition: ->
    @cursor.getScreenPosition()

  removeIdleClassTemporarily: ->
    @removeClass 'idle'
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @idleTimeout = window.setTimeout (=> @addClass 'idle'), 200

  resetCursorAnimation: ->
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @removeClass 'idle'
    _.defer => @addClass 'idle'
