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
    {performedInitialMeasurement, cursorPixelRects, defaultCharWidth} = @props
    {blinkOff} = @state

    className = 'cursors'
    className += ' blink-off' if blinkOff

    div {className},
      if performedInitialMeasurement
        for key, pixelRect of cursorPixelRects
          CursorComponent({key, pixelRect, defaultCharWidth})

  getInitialState: ->
    blinkOff: false

  componentDidMount: ->
    @startBlinkingCursors()

  componentWillUnmount: ->
    @stopBlinkingCursors()

  shouldComponentUpdate: (newProps, newState) ->
    not newState.blinkOff is @state.blinkOff or
      not isEqualForProperties(newProps, @props, 'cursorPixelRects', 'scrollTop', 'scrollLeft', 'defaultCharWidth', 'useHardwareAcceleration')

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
