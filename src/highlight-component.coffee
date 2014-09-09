React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
HighlightComponent = React.createClass
  displayName: 'HighlightComponent'

  render: ->
    {startPixelPosition, endPixelPosition, decoration} = @props

    className = 'highlight'
    className += " #{decoration.class}" if decoration.class?

    div {className},
      if endPixelPosition.top is startPixelPosition.top
        @renderSingleLineRegions()
      else
        @renderMultiLineRegions()

  componentDidMount: ->
    {editor, decoration} = @props
    if decoration.id?
      @decoration = editor.decorationForId(decoration.id)
      @decorationDisposable = @decoration.onDidFlash @startFlashAnimation
      @startFlashAnimation()

  componentWillUnmount: ->
    @decorationDisposable?.dispose()
    @decorationDisposable = null

  startFlashAnimation: ->
    return unless flash = @decoration.consumeNextFlash()

    node = @getDOMNode()
    node.classList.remove(flash.class)

    requestAnimationFrame =>
      node.classList.add(flash.class)
      clearTimeout(@flashTimeoutId)
      removeFlashClass = -> node.classList.remove(flash.class)
      @flashTimeoutId = setTimeout(removeFlashClass, flash.duration)

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

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'startPixelPosition', 'endPixelPosition', 'lineHeightInPixels')
