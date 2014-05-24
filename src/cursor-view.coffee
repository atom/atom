{View} = require './space-pen-extensions'
_ = require 'underscore-plus'

module.exports =
class CursorView extends View
  @content: ->
    @div class: 'cursor idle', => @raw '&nbsp;'

  @blinkPeriod: 800

  @blinkCursors: ->
    element.classList.toggle('blink-off') for [element] in @cursorViews

  @startBlinking: (cursorView) ->
    @cursorViews ?= []
    @cursorViews.push(cursorView)
    if @cursorViews.length is 1
      @blinkInterval = setInterval(@blinkCursors.bind(this), @blinkPeriod / 2)

  @stopBlinking: (cursorView) ->
    cursorView[0].classList.remove('blink-off')
    _.remove(@cursorViews, cursorView)
    clearInterval(@blinkInterval) if @cursorViews.length is 0

  blinking: false
  visible: true
  needsUpdate: true
  needsRemoval: false
  shouldPauseBlinking: false

  initialize: (@cursor, @editorView) ->
    @subscribe @cursor, 'moved', =>
      @needsUpdate = true
      @shouldPauseBlinking = true

    @subscribe @cursor, 'visibility-changed', =>
      @needsUpdate = true

    @subscribe @cursor, 'autoscrolled', =>
      @editorView.requestDisplayUpdate()

    @subscribe @cursor, 'destroyed', =>
      @needsRemoval = true

  beforeRemove: ->
    @editorView.removeCursorView(this)
    @stopBlinking()

  updateDisplay: ->
    screenPosition = @getScreenPosition()
    pixelPosition = @getPixelPosition()

    unless _.isEqual(@lastPixelPosition, pixelPosition)
      @lastPixelPosition = pixelPosition
      @css(pixelPosition)
      @trigger 'cursor:moved'

    if @shouldPauseBlinking
      @resetBlinking()
    else if !@startBlinkingTimeout
      @startBlinking()

    @setVisible(@cursor.isVisible() and not @editorView.getEditor().isFoldedAtScreenRow(screenPosition.row))

  # Override for speed. The base function checks the computedStyle
  isHidden: ->
    this[0].style.display is 'none' or not @isOnDom()

  needsAutoscroll: ->
    @cursor.needsAutoscroll

  clearAutoscroll: ->
    @cursor.clearAutoscroll()

  getPixelPosition: ->
    @editorView.pixelPositionForScreenPosition(@getScreenPosition())

  setVisible: (visible) ->
    unless @visible is visible
      @visible = visible
      hiddenCursor = 'hidden-cursor'
      if visible
        @removeClass hiddenCursor
      else
        @addClass hiddenCursor

  stopBlinking: ->
    @constructor.stopBlinking(this) if @blinking
    @blinking = false

  startBlinking: ->
    @constructor.startBlinking(this) unless @blinking
    @blinking = true

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
