React = require 'react'
{div} = require 'reactionary'
{debounce} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'
CursorComponent = require './cursor-component'


module.exports =
CursorsComponent = React.createClass
  mixins: [SubscriberMixin]

  cursorBlinkIntervalHandle: null

  render: ->
    {editor} = @props
    {blinkCursorsOff} = @state

    div className: 'cursors',
      for selection in editor.getSelections() when editor.selectionIntersectsVisibleRowRange(selection)
        CursorComponent(cursor: selection.cursor, blinkOff: blinkCursorsOff)

  getInitialState: ->
    blinkCursorsOff: false

  componentDidMount: ->
    {editor} = @props
    @subscribe editor, 'cursors-moved', @pauseCursorBlinking
    @startBlinkingCursors()

  startBlinkingCursors: ->
    @cursorBlinkIntervalHandle = setInterval(@toggleCursorBlink, @props.cursorBlinkPeriod / 2)

  startBlinkingCursorsAfterDelay: null # Created lazily

  stopBlinkingCursors: ->
    clearInterval(@cursorBlinkIntervalHandle)
    @setState(blinkCursorsOff: false)

  toggleCursorBlink: -> @setState(blinkCursorsOff: not @state.blinkCursorsOff)

  pauseCursorBlinking: ->
    @stopBlinkingCursors()
    @startBlinkingCursorsAfterDelay ?= debounce(@startBlinkingCursors, @props.cursorBlinkResumeDelay)
    @startBlinkingCursorsAfterDelay()
