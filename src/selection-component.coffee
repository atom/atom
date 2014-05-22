React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports =
SelectionComponent = React.createClass
  displayName: 'SelectionComponent'

  render: ->
    {editor, screenRange, lineHeightInPixels} = @props
    {start, end} = screenRange
    rowCount = end.row - start.row + 1
    startPixelPosition = editor.pixelPositionForScreenPosition(start)
    endPixelPosition = editor.pixelPositionForScreenPosition(end)

    div className: 'selection',
      if rowCount is 1
        @renderSingleLineRegions(startPixelPosition, endPixelPosition)
      else
        @renderMultiLineRegions(startPixelPosition, endPixelPosition, rowCount)

  renderSingleLineRegions: (startPixelPosition, endPixelPosition) ->
    {lineHeightInPixels} = @props

    [
      div className: 'region', key: 0, style:
        top: startPixelPosition.top
        height: lineHeightInPixels
        left: startPixelPosition.left
        width: endPixelPosition.left - startPixelPosition.left
    ]

  renderMultiLineRegions: (startPixelPosition, endPixelPosition, rowCount) ->
    {lineHeightInPixels} = @props
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
    if rowCount > 2
      regions.push(
        div className: 'region', key: index++, style:
          top: startPixelPosition.top + lineHeightInPixels
          height: (rowCount - 2) * lineHeightInPixels
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
