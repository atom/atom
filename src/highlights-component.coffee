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
    {editor, decorationsByMarkerId, lineHeightInPixels} = @props

    highlightComponents = []
    for markerId, decorations of decorationsByMarkerId
      if decorations?
        for decoration in decorations
          highlightComponents.push(HighlightComponent({key: "#{markerId}-#{decoration.class}", decoration, editor, lineHeightInPixels}))
    highlightComponents

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'decorationsByMarkerId', 'lineHeightInPixels', 'defaultCharWidth')
