Point = require 'point'
Buffer = require 'buffer'

module.exports =
class EditSession
  @deserialize: (state, rootView) ->
    buffer = Buffer.deserialize(state.buffer, rootView.project)
    session = new EditSession(buffer)
    session.setScrollTop(state.scrollTop)
    session.setScrollLeft(state.scrollLeft)
    session.setCursorScreenPosition(state.cursorScreenPosition)
    session

  scrollTop: 0
  scrollLeft: 0
  cursorScreenPosition: null

  constructor: (@buffer) ->
    @setCursorScreenPosition([0, 0])

  serialize: ->
    buffer: @buffer.serialize()
    scrollTop: @getScrollTop()
    scrollLeft: @getScrollLeft()
    cursorScreenPosition: @getCursorScreenPosition().serialize()

  setScrollTop: (@scrollTop) ->
  getScrollTop: -> @scrollTop

  setScrollLeft: (@scrollLeft) ->
  getScrollLeft: -> @scrollLeft

  setCursorScreenPosition: (position) ->
    @cursorScreenPosition = Point.fromObject(position)

  getCursorScreenPosition: ->
    @cursorScreenPosition

