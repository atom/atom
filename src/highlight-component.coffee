React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
HighlightComponent = React.createClass
  displayName: 'HighlightComponent'

  render: ->
    {startPixelPosition, endPixelPosition, decoration} = @props
    {flash} = @state

    className = 'highlight'
    className += " #{decoration.class}" if decoration.class?

    if flash?
      className += " #{flash.class}"
      @flashTimeout = setTimeout(@turnOffFlash, flash.duration ? 500)

    div {className},
      if endPixelPosition.top is startPixelPosition.top
        @renderSingleLineRegions()
      else
        @renderMultiLineRegions()

  componentWillMount: ->
    @state.flash = @props.decoration.flash

  componentWillUpdate: (newProps) ->
    if newProps.decoration.flash?
      if @flashTimeout?
        # This happens when re-rendered before the flash finishes. We need to
        # render _without_ the flash class first, then re-render with the
        # flash class. Otherwise there will be no flash.
        clearTimeout(@flashTimeout)
        setImmediate => @setState(flash: newProps.decoration.flash)
        @flashTimeout = null
        @state.flash = null
      else
        @state.flash = newProps.decoration.flash

  turnOffFlash: ->
    clearTimeout(@flashTimeout)
    @flashTimeout = null
    @setState(flash: null)

  renderSingleLineRegions: ->
    {startPixelPosition, endPixelPosition, lineHeightInPixels} = @props

    [
      div className: 'region', key: 0, style:
        top: startPixelPosition.top
        height: lineHeightInPixels
        left: startPixelPosition.left
        width: endPixelPosition.left - startPixelPosition.left
    ]

  renderMultiLineRegions: ->
    {startPixelPosition, endPixelPosition, lineHeightInPixels} = @props
    regions = []
    index = 0

    # First row, extending from selection start to the right side of screen
    regions.push(
      div className: 'region', key: index++, style:
        top: startPixelPosition.top
        left: startPixelPosition.left
        height: lineHeightInPixels
        right: 0
    )

    # Middle rows, extending from left side to right side of screen
    if endPixelPosition.top - startPixelPosition.top > lineHeightInPixels
      regions.push(
        div className: 'region', key: index++, style:
          top: startPixelPosition.top + lineHeightInPixels
          height: endPixelPosition.top - startPixelPosition.top - lineHeightInPixels
          left: 0
          right: 0
      )

    # Last row, extending from left side of screen to selection end
    regions.push(
      div className: 'region', key: index, style:
        top: endPixelPosition.top
        height: lineHeightInPixels
        left: 0
        width: endPixelPosition.left
    )

    regions

  shouldComponentUpdate: (newProps, newState) ->
    newState.flash isnt @state.flash or not isEqualForProperties(newProps, @props, 'startPixelPosition', 'endPixelPosition', 'lineHeightInPixels')
