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
    {editor} = @props
    blinkOff = @state.blinkCursorsOff

    div className: 'cursors',
      for selection in editor.getSelections() when editor.selectionIntersectsVisibleRowRange(selection)
        {cursor} = selection
        CursorComponent({key: cursor.id, cursor, blinkOff})

  getInitialState: ->
    blinkCursorsOff: false

  componentDidMount: ->
    {editor} = @props
    @subscribe editor, 'cursors-moved', @pauseCursorBlinking
    @startBlinkingCursors()

  componentWillUnmount: ->
    @stopBlinkingCursors()

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
