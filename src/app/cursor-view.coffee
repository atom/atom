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
    @anchor = new Anchor(@editor, cursor.getScreenPosition())
    @selection = @editor.compositeSelection.addSelectionForCursor(this)
    @cursor.on 'change-screen-position', (position, options) =>
      options.fromModel = true
      @setScreenPosition(position, options)
    @cursor.on 'destroy', => @remove()

  afterAttach: (onDom) ->
    return unless onDom
    @updateAppearance()
    @editor.syncCursorAnimations()

  remove: ->
    @editor.compositeCursor.removeCursor(this)
    @editor.compositeSelection.removeSelectionForCursor(this)
    @cursor.off()
    super

  getBufferPosition: ->
    @cursor.getBufferPosition()

  setBufferPosition: (bufferPosition, options={}) ->
    @cursor.setBufferPosition(bufferPosition, options)

  getScreenPosition: ->
    @anchor.getScreenPosition()

  setScreenPosition: (position, options={}) ->
    if options.fromModel
      @anchor.setScreenPosition(position, options)
      @refreshScreenPosition()
      @trigger 'cursor-move', bufferChange: options.bufferChange
      @clearSelection() unless options.bufferChange
    else
      @cursor.setScreenPosition(position, options)

  refreshScreenPosition: ->
    @goalColumn = null
    @updateAppearance()

    @removeClass 'idle'
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @idleTimeout = window.setTimeout (=> @addClass 'idle'), 200

  resetCursorAnimation: ->
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @removeClass 'idle'
    _.defer => @addClass 'idle'

  clearSelection: ->
    @selection.clearSelection() unless @selection.retainSelection

  getCurrentBufferLine: ->
    @editor.lineForBufferRow(@getBufferPosition().row)

  isOnEOL: ->
    @getScreenPosition().column == @getCurrentBufferLine().length

  updateAppearance: ->
    screenPosition = @getScreenPosition()
    pixelPosition = @editor.pixelPositionForScreenPosition(screenPosition)
    @css(pixelPosition)

    if this == _.last(@editor.getCursors())
      @editor.scrollTo(pixelPosition)

    if @editor.isFoldedAtScreenRow(screenPosition.row)
      @hide() unless @hidden
      @hidden = true
    else
      @show() if @hidden
      @hidden = false

    @selection.updateAppearance()
