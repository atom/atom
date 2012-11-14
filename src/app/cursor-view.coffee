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

  needsUpdate: true
  needsAutoscroll: true
  needsRemoval: false

  initialize: (@cursor, @editor) ->
    @cursor.on 'change-screen-position.cursor-view', (screenPosition, { bufferChange, autoscroll }) =>
      @needsUpdate = true
      @needsAutoscroll = (autoscroll ? true) and @cursor?.isLastCursor()
      @editor.requestDisplayUpdate()

      # TODO: Move idle/active to the cursor model
#       @removeIdleClassTemporarily() unless bufferChange
      @trigger 'cursor-move', {bufferChange}

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

    @setVisible(@cursor.isVisible() and not @editor.isFoldedAtScreenRow(screenPosition.row))

  getPixelPosition: ->
    @editor.pixelPositionForScreenPosition(@getScreenPosition())

  setVisible: (visible) ->
    unless @visible == visible
      @visible = visible
      @toggle(@visible)

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
