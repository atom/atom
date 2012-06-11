{View} = require 'space-pen'
Anchor = require 'anchor'
Point = require 'point'
Range = require 'range'
_ = require 'underscore'

module.exports =
class CursorView extends View
  @content: ->
    @pre class: 'cursor idle', => @raw '&nbsp;'

  anchor: null
  editor: null
  hidden: false

  initialize: (@cursor, @editor) ->
    @cursor.on 'change-screen-position', (position, options) =>
      @updateAppearance()
      unless options.bufferChange
        @removeIdleClassTemporarily()
      @trigger 'cursor-move', bufferChange: options.bufferChange

    @cursor.on 'destroy', => @remove()

  afterAttach: (onDom) ->
    return unless onDom
    @updateAppearance()
    @editor.syncCursorAnimations()

  remove: ->
    @editor.compositeCursor.removeCursorView(this)
    @cursor.off()
    super

  updateAppearance: ->
    screenPosition = @getScreenPosition()
    pixelPosition = @editor.pixelPositionForScreenPosition(screenPosition)
    @css(pixelPosition)

    if @cursor == @editor.getLastCursor()
      @editor.scrollTo(pixelPosition)

    if @editor.isFoldedAtScreenRow(screenPosition.row)
      @hide() unless @hidden
      @hidden = true
    else
      @show() if @hidden
      @hidden = false

    @getSelectionView()?.updateAppearance()

  getSelectionView: ->
    @editor.compositeSelection.selectionViewForCursor(@cursor)

  getBufferPosition: ->
    @cursor.getBufferPosition()

  setBufferPosition: (bufferPosition, options={}) ->
    @cursor.setBufferPosition(bufferPosition, options)

  getScreenPosition: ->
    @cursor.getScreenPosition()

  setScreenPosition: (position, options={}) ->
    @cursor.setScreenPosition(position, options)

  removeIdleClassTemporarily: ->
    @removeClass 'idle'
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @idleTimeout = window.setTimeout (=> @addClass 'idle'), 200

  resetCursorAnimation: ->
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @removeClass 'idle'
    _.defer => @addClass 'idle'
