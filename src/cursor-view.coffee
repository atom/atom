{View} = require './space-pen-extensions'
{Point, Range} = require 'telepath'
_ = require './underscore-extensions'

### Internal ###
module.exports =
class CursorView extends View
  @content: ->
    @div class: 'cursor idle', => @raw '&nbsp;'

  blinkPeriod: 800
  editor: null
  visible: true

  needsUpdate: true
  needsRemoval: false
  shouldPauseBlinking: false

  initialize: (@cursor, @editor) ->
    @cursor.on 'moved.cursor-view', =>
      @needsUpdate = true
      @shouldPauseBlinking = true

    @cursor.on 'visibility-changed.cursor-view', (visible) =>
      @needsUpdate = true

    @cursor.on 'autoscrolled.cursor-view', =>
      @editor.requestDisplayUpdate()

    @cursor.on 'destroyed.cursor-view', =>
      @needsRemoval = true

    if @cursor.marker.isRemote()
      @addClass("site-#{@cursor.marker.getOriginSiteId()}")

  beforeRemove: ->
    @editor.removeCursorView(this)
    @cursor.off('.cursor-view')
    @stopBlinking()

  updateDisplay: ->
    screenPosition = @getScreenPosition()
    pixelPosition = @getPixelPosition()

    unless _.isEqual(@lastPixelPosition, pixelPosition)
      changedPosition = true
      @css(pixelPosition)
      @trigger 'cursor:moved'

    if @shouldPauseBlinking
      @resetBlinking()
    else if !@startBlinkingTimeout
      @startBlinking()

    @setVisible(@cursor.isVisible() and not @editor.isFoldedAtScreenRow(screenPosition.row))

  # Override for speed. The base function checks the computedStyle
  isHidden: ->
    style = this[0].style
    if style.display == 'none' or not @isOnDom()
      true
    else
      false

  needsAutoscroll: ->
    @cursor.needsAutoscroll

  clearAutoscroll: ->
    @cursor.clearAutoscroll()

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
