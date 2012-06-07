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

  destroy: ->
    @editSession.removeCursor(this)
    @trigger 'destroy'

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

  getBufferRow: ->
    @getBufferPosition().row

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

  moveToBeginningOfLine: ->
    @setBufferPosition([@getBufferRow(), 0])

  moveToFirstCharacterOfLine: ->
    position = @getBufferPosition()
    range = @editSession.bufferRangeForBufferRow(position.row)
    newPosition = null
    @editSession.scanInRange /^\s*/, range, (match, matchRange) =>
      newPosition = matchRange.end
    return unless newPosition
    newPosition = [position.row, 0] if newPosition.isEqual(position)
    @setBufferPosition(newPosition)

  moveToEndOfLine: ->
    @setBufferPosition([@getBufferRow(), Infinity], clip: true)

_.extend Cursor.prototype, EventEmitter
