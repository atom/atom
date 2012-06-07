Point = require 'point'
Anchor = require 'new-anchor'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

module.exports =
class Cursor
  screenPosition: null
  bufferPosition: null
  goalColumn: null

  constructor: ({@editSession, screenPosition, bufferPosition}) ->
    @anchor = new Anchor(@editSession)
    @setScreenPosition(screenPosition) if screenPosition
    @setBufferPosition(bufferPosition) if bufferPosition

  setScreenPosition: (screenPosition, options) ->
    @anchor.setScreenPosition(screenPosition, options)
    @goalColumn = null
    @trigger 'change-screen-position', @getScreenPosition(), bufferChange: false

  getScreenPosition: ->
    @anchor.getScreenPosition()

  setBufferPosition: (bufferPosition, options) ->
    @anchor.setBufferPosition(bufferPosition, options)
    @goalColumn = null
    @trigger 'change-screen-position', @getScreenPosition(), bufferChange: false

  getBufferPosition: ->
    @anchor.getBufferPosition()

  handleBufferChange: (e) ->
    @anchor.handleBufferChange(e)
    @trigger 'change-screen-position', @getScreenPosition(), bufferChange: true

  moveUp: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row - 1, column: column})
    @goalColumn = column

  moveDown: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row + 1, column: column})
    @goalColumn = column

  moveLeft: ->
    { row, column } = @getScreenPosition()
    [row, column] = if column > 0 then [row, column - 1] else [row - 1, Infinity]
    @setScreenPosition({row, column})

  moveRight: ->
    { row, column } = @getScreenPosition()
    @setScreenPosition([row, column + 1], skipAtomicTokens: true, wrapBeyondNewlines: true, wrapAtSoftNewlines: true)

  moveToTop: ->
    @setBufferPosition([0,0])

  moveToBottom: ->
    @setBufferPosition(@editSession.getEofBufferPosition())

  destroy: ->
    @editSession.removeCursor(this)
    @trigger 'destroy'

_.extend Cursor.prototype, EventEmitter
