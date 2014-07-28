React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
CursorComponent = React.createClass
  displayName: 'CursorComponent'

  render: ->
    {pixelRect, defaultCharWidth} = @props
    {top, left, height, width} = pixelRect
    width = defaultCharWidth if width is 0
    WebkitTransform = "translate(#{left}px, #{top}px)"

    div className: 'cursor', style: {height, width, WebkitTransform}

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'pixelRect', 'defaultCharWidth')
