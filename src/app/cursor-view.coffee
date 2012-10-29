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
    @cursor.on 'change-screen-position.cursor-view', (screenPosition, { bufferChange }) =>
      @updateAppearance()
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

  updateAppearance: ->
    screenPosition = @getScreenPosition()
    pixelPosition = @editor.pixelPositionForScreenPosition(screenPosition)
    @css(pixelPosition)

    if @cursor == @editor.getLastCursor()
      @editor.scrollTo(pixelPosition)

    @setVisible(@cursor.isVisible() and not @editor.isFoldedAtScreenRow(screenPosition.row))

  setVisible: (visible) ->
    return if visible == @visible
    @visible = visible

    if @visible
      @show()
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
