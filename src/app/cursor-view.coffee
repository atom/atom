{View} = require 'space-pen'
Anchor = require 'app/anchor'
Point = require 'app/point'
Range = require 'app/range'
_ = require 'underscore'

module.exports =
class CursorView extends View
  @content: ->
    @pre class: 'cursor idle', => @raw '&nbsp;'

  blinkPeriod: 800
  editor: null
  visible: true

  needsUpdate: true
  needsRemoval: false
  shouldPauseBlinking: false

  initialize: (@cursor, @editor) ->
    @cursor.on 'moved.cursor-view', ({ autoscroll }) =>
      @needsUpdate = true
      @shouldPauseBlinking = true
      @editor.requestDisplayUpdate()

    @cursor.on 'change-visibility.cursor-view', (visible) =>
      @needsUpdate = true
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

  needsAutoscroll: ->
    @cursor.needsAutoscroll

  autoscrolled: ->
    @cursor.autoscrolled()

  getPixelPosition: ->
    @editor.pixelPositionForScreenPosition(@getScreenPosition())

  setVisible: (visible) ->
    unless @visible == visible
      @visible = visible
      @toggle(@visible)

  stopBlinking: ->
    clearInterval(@blinkInterval) if @blinkInterval
    @blinkInterval = null
    this[0].classList.remove('blink-off')

  startBlinking: ->
    return if @blinkInterval?
    blink = => @toggleClass('blink-off')
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
