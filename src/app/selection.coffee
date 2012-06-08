Range = require 'range'
Anchor = require 'new-anchor'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

module.exports =
class Selection
  anchor: null

  constructor: ({@cursor, @editSession}) ->
    @cursor.on 'change-screen-position', (e) =>
      @trigger 'change-screen-range', @getScreenRange() unless e.bufferChanged

  getScreenRange: ->
    if @anchor
      new Range(@anchor.getScreenPosition(), @cursor.getScreenPosition())
    else
      new Range(@cursor.getScreenPosition(), @cursor.getScreenPosition())

  setScreenRange: (screenRange, options={})->
    screenRange = Range.fromObject(screenRange)
    { start, end } = screenRange
    [start, end] = [end, start] if options.reverse

    @modifyScreenRange =>
      @placeAnchor() unless @anchor
      @modifySelection =>
        @anchor.setScreenPosition(start)
        @cursor.setScreenPosition(end)

  getBufferRange: ->
    if @anchor
      new Range(@anchor.getBufferPosition(), @cursor.getBufferPosition())
    else
      new Range(@cursor.getBufferPosition(), @cursor.getBufferPosition())

  clear: ->
    @modifyScreenRange => @anchor = null

  isEmpty: ->
    @getBufferRange().isEmpty()

  isReversed: ->
    not @isEmpty() and @cursor.getBufferPosition().isLessThan(@anchor.getBufferPosition())

  handleBufferChange: (e) ->
    @modifyScreenRange =>
      @anchor?.handleBufferChange(e)
      @cursor.handleBufferChange(e)

  modifySelection: (fn) ->
    @retainSelection = true
    @view?.retainSelection = true
    @placeAnchor() unless @anchor
    fn()
    @retainSelection = false
    @view?.retainSelection = false

  modifyScreenRange: (fn) ->
    oldScreenRange = @getScreenRange()
    fn()
    newScreenRange = @getScreenRange()
    @trigger 'change-screen-range', newScreenRange unless oldScreenRange.isEqual(newScreenRange)

  placeAnchor: ->
    @anchor = new Anchor(@editSession)
    @anchor.setScreenPosition(@cursor.getScreenPosition())

_.extend Selection.prototype, EventEmitter
