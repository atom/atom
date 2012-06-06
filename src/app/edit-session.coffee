Point = require 'point'
Buffer = require 'buffer'
Renderer = require 'renderer'

module.exports =
class EditSession
  @deserialize: (state, editor, rootView) ->
    buffer = Buffer.deserialize(state.buffer, rootView.project)
    session = new EditSession(editor, buffer)
    session.setScrollTop(state.scrollTop)
    session.setScrollLeft(state.scrollLeft)
    session.setCursorScreenPosition(state.cursorScreenPosition)
    session

  scrollTop: 0
  scrollLeft: 0
  cursorScreenPosition: null
  renderer: null

  constructor: (@editor, @buffer) ->
    @setCursorScreenPosition([0, 0])

  serialize: ->
    buffer: @buffer.serialize()
    scrollTop: @getScrollTop()
    scrollLeft: @getScrollLeft()
    cursorScreenPosition: @getCursorScreenPosition().serialize()

  getRenderer: ->
    @renderer ?= new Renderer(@buffer, { softWrapColumn: @editor.calcSoftWrapColumn(), tabText: @editor.tabText })

  setScrollTop: (@scrollTop) ->
  getScrollTop: -> @scrollTop

  setScrollLeft: (@scrollLeft) ->
  getScrollLeft: -> @scrollLeft

  setCursorScreenPosition: (position) ->
    @cursorScreenPosition = Point.fromObject(position)

  getCursorScreenPosition: ->
    @cursorScreenPosition

  isEqual: (other) ->
    return false unless other instanceof EditSession
    @buffer == other.buffer and
      @scrollTop == other.getScrollTop() and
      @scrollLeft == other.getScrollLeft() and
      @cursorScreenPosition.isEqual(other.getCursorScreenPosition())
