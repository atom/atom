React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'
HighlightComponent = require './highlight-component'

module.exports =
HighlightsComponent = React.createClass
  displayName: 'HighlightsComponent'

  render: ->
    if @isMounted()
      {scrollTop, scrollLeft, scrollHeight, scrollWidth} = @props
      style =
        height: scrollHeight
        width: scrollWidth
        WebkitTransform: "translate3d(#{-scrollLeft}px, #{-scrollTop}px, 0px)"

    div {className: 'highlights', style},
      @renderHighlights() if @isMounted()


  renderHighlights: ->
    {editor, highlightDecorations, lineHeightInPixels} = @props

    highlightComponents = []
    for markerId, {screenRange, decorations} of highlightDecorations
      for decoration in decorations
        highlightComponents.push(HighlightComponent({key: "#{markerId}-#{decoration.class}", screenRange, decoration, editor, lineHeightInPixels}))

    highlightComponents

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props,
      'scrollTop', 'scrollLeft', 'highlightDecorations', 'lineHeightInPixels',
      'defaultCharWidth', 'scopedCharacterWidthsChangeCount'
    )
