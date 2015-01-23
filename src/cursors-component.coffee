React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{debounce, toArray, isEqualForProperties, isEqual} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'
CursorComponent = require './cursor-component'

module.exports =
CursorsComponent = React.createClass
  displayName: 'CursorsComponent'
  mixins: [SubscriberMixin]

  cursorBlinkIntervalHandle: null

  render: ->
    {presenter, defaultCharWidth} = @props
    {blinkOff} = @state

    className = 'cursors'
    className += ' blink-off' if blinkOff

    div {className},
      if presenter?
        for key, pixelRect of presenter.state.content.cursors
          CursorComponent({key, pixelRect})

  getInitialState: ->
    blinkOff: false

  componentDidMount: ->
    @startBlinkingCursors()

  componentWillUnmount: ->
    @stopBlinkingCursors()

  componentWillUpdate: (newProps) ->
    cursorsMoved = @props.cursorPixelRects? and
      isEqualForProperties(newProps, @props, 'defaultCharWidth', 'scopedCharacterWidthsChangeCount') and
      not isEqual(newProps.cursorPixelRects, @props.cursorPixelRects)

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
