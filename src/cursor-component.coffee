React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
CursorComponent = React.createClass
  displayName: 'CursorComponent'

  render: ->
    {pixelRect, scrollTop, scrollLeft, defaultCharWidth} = @props
    {top, left, height, width} = pixelRect
    top -= scrollTop
    left -= scrollLeft
    width = defaultCharWidth if width is 0
    WebkitTransform = "translate3d(#{left}px, #{top}px, 0px)"

    div className: 'cursor', style: {height, width, WebkitTransform}

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'pixelRect', 'scrollTop', 'scrollLeft', 'defaultCharWidth')
