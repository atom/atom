Point = require 'point'
Anchor = require 'new-anchor'

module.exports =
class Cursor
  screenPosition: null
  bufferPosition: null

  constructor: ({@editSession, screenPosition, bufferPosition}) ->
    @anchor = new Anchor(@editSession)
    @setScreenPosition(screenPosition) if screenPosition
    @setBufferPosition(bufferPosition) if bufferPosition

  setScreenPosition: (screenPosition) ->
    @anchor.setScreenPosition(screenPosition)

  getScreenPosition: ->
    @anchor.getScreenPosition()

  setBufferPosition: (bufferPosition) ->
    @anchor.setBufferPosition(bufferPosition)

  getBufferPosition: ->
    @anchor.getBufferPosition()

