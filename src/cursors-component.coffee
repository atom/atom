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
    {editor, cursorScreenRanges, scrollTop, scrollLeft} = @props
    {blinkOff} = @state

    className = 'cursors'
    className += ' blink-off' if blinkOff

    div {className},
      if @isMounted()
        for key, screenRange of cursorScreenRanges
          CursorComponent({key, editor, screenRange, scrollTop, scrollLeft})

  getInitialState: ->
    blinkOff: false

  componentDidMount: ->
    @startBlinkingCursors()

  componentWillUnmount: ->
    @stopBlinkingCursors()

  shouldComponentUpdate: (newProps, newState) ->
    not newState.blinkOff is @state.blinkOff or
      not isEqualForProperties(newProps, @props, 'cursorScreenRanges', 'scrollTop', 'scrollLeft', 'lineHeightInPixels', 'defaultCharWidth')

  componentWillUpdate: (newProps) ->
    @pauseCursorBlinking() if @props.cursorScreenRanges and not isEqual(newProps.cursorScreenRanges, @props.cursorScreenRanges)

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
