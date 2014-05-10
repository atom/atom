React = require 'react'
{div} = require 'reactionary'
{debounce} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'
CursorComponent = require './cursor-component'


module.exports =
CursorsComponent = React.createClass
  displayName: 'CursorsComponent'
  mixins: [SubscriberMixin]

  cursorBlinkIntervalHandle: null

  render: ->
    {editor, scrollTop} = @props
    blinkOff = @state.blinkCursorsOff

    div className: 'cursors',
      if @isMounted()
        for selection in editor.getSelections()
          if selection.isEmpty() and editor.selectionIntersectsVisibleRowRange(selection)
            {cursor} = selection
            CursorComponent({key: cursor.id, cursor, scrollTop, blinkOff})

  getInitialState: ->
    blinkCursorsOff: false

  componentDidMount: ->
    {editor} = @props
    @startBlinkingCursors()

  componentWillUnmount: ->
    clearInterval(@cursorBlinkIntervalHandle)

  componentWillUpdate: ({cursorsMoved}) ->
    @pauseCursorBlinking() if cursorsMoved

  startBlinkingCursors: ->
    @cursorBlinkIntervalHandle = setInterval(@toggleCursorBlink, @props.cursorBlinkPeriod / 2)

  startBlinkingCursorsAfterDelay: null # Created lazily

  toggleCursorBlink: -> @setState(blinkCursorsOff: not @state.blinkCursorsOff)

  pauseCursorBlinking: ->
    @state.blinkCursorsOff = false
    clearInterval(@cursorBlinkIntervalHandle)
    @startBlinkingCursorsAfterDelay ?= debounce(@startBlinkingCursors, @props.cursorBlinkResumeDelay)
    @startBlinkingCursorsAfterDelay()
