React = require 'react'
{div} = require 'reactionary'
{debounce, toArray} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'
CursorComponent = require './cursor-component'

module.exports =
CursorsComponent = React.createClass
  displayName: 'CursorsComponent'
  mixins: [SubscriberMixin]

  cursorBlinkIntervalHandle: null

  render: ->
    {editor, scrollTop, scrollLeft} = @props
    {blinkOff} = @state

    className = 'cursors'
    className += ' blink-off' if blinkOff

    div {className},
      if @isMounted()
        for selection in editor.getSelections()
          if selection.isEmpty() and editor.selectionIntersectsVisibleRowRange(selection)
            {cursor} = selection
            CursorComponent({key: cursor.id, cursor, scrollTop, scrollLeft})

  getInitialState: ->
    blinkOff: false

  componentDidMount: ->
    @startBlinkingCursors()

  componentWillUnmount: ->
    @stopBlinkingCursors()

  componentWillUpdate: ({cursorsMoved}) ->
    @pauseCursorBlinking() if cursorsMoved

  startBlinkingCursors: ->
    @toggleCursorBlinkHandle = setInterval(@toggleCursorBlink, @props.cursorBlinkPeriod / 2) if @isMounted()

  startBlinkingCursorsAfterDelay: null # Created lazily

  stopBlinkingCursors: ->
    clearInterval(@toggleCursorBlinkHandle)

  toggleCursorBlink: ->
    @setState(blinkOff: not @state.blinkOff)

  pauseCursorBlinking: ->
    @state.blinkOff = false
    @stopBlinkingCursors()
    @startBlinkingCursorsAfterDelay ?= debounce(@startBlinkingCursors, @props.cursorBlinkResumeDelay)
    @startBlinkingCursorsAfterDelay()
