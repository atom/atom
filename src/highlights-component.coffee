React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'
HighlightComponent = require './highlight-component'

module.exports =
HighlightsComponent = React.createClass
  displayName: 'HighlightsComponent'

  render: ->
    div className: 'highlights', @renderHighlights()

  renderHighlights: ->
    {editor, highlightDecorations, lineHeightInPixels} = @props

    highlightComponents = []
    for markerId, {screenRange, decorations} of highlightDecorations
      for decoration in decorations
        highlightComponents.push(HighlightComponent({key: "#{markerId}-#{decoration.class}", screenRange, decoration, editor, lineHeightInPixels}))

    highlightComponents

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'highlightDecorations', 'lineHeightInPixels', 'defaultCharWidth', 'scopedCharacterWidthsChangeCount')
