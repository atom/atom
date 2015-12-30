React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'
HighlightComponent = require './highlight-component'

module.exports =
HighlightsComponent = React.createClass
  displayName: 'HighlightsComponent'

  render: ->
    div className: 'highlights',
      @renderHighlights() if @props.performedInitialMeasurement

  renderHighlights: ->
    {editor, highlightDecorations, lineHeightInPixels} = @props

    highlightComponents = []
    for markerId, {startPixelPosition, endPixelPosition, decorations} of highlightDecorations
      for decoration in decorations
        highlightComponents.push(HighlightComponent({editor, key: "#{markerId}-#{decoration.class}", startPixelPosition, endPixelPosition, decoration, lineHeightInPixels}))

    highlightComponents

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'highlightDecorations', 'lineHeightInPixels', 'defaultCharWidth', 'scopedCharacterWidthsChangeCount')
