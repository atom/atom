{View} = require 'space-pen'
Anchor = require 'anchor'
Point = require 'point'
Range = require 'range'
_ = require 'underscore'

module.exports =
class CursorView extends View
  @content: ->
    @pre class: 'cursor idle', => @raw '&nbsp;'

  editor: null
  visible: true

  initialize: (@cursor, @editor) ->
    @cursor.on 'change-screen-position.cursor-view', (screenPosition, { bufferChange, autoscroll }) =>
      @updateAppearance({autoscroll})
      @removeIdleClassTemporarily() unless bufferChange
      @trigger 'cursor-move', {bufferChange}

    @cursor.on 'change-visibility.cursor-view', (visible) => @setVisible(visible)
    @cursor.on 'destroy.cursor-view', => @remove()

  afterAttach: (onDom) ->
    return unless onDom
    @updateAppearance()
    @editor.syncCursorAnimations()

  remove: ->
    @editor.removeCursorView(this)
    @cursor.off('.cursor-view')
    super

  updateAppearance: (options={}) ->
    screenPosition = @getScreenPosition()
    pixelPosition = @getPixelPosition()
    @css(pixelPosition)

    if @cursor == @editor.getLastCursor()
      @autoscroll() if options.autoscroll ? true
      @editor.hiddenInput.css(pixelPosition)

    @setVisible(@cursor.isVisible() and not @editor.isFoldedAtScreenRow(screenPosition.row))

  getPixelPosition: ->
    @editor.pixelPositionForScreenPosition(@getScreenPosition())

  autoscroll: ->
    @editor.scrollTo(@getPixelPosition())

  setVisible: (visible) ->
    return if visible == @visible
    @visible = visible

    if @visible
      @show()
      @autoscroll()
    else
      @hide()

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
