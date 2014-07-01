React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
CursorComponent = React.createClass
  displayName: 'CursorComponent'

  render: ->
    {pixelRect, defaultCharWidth} = @props
    {height, width} = pixelRect
    width = defaultCharWidth if width is 0
    WebkitTransform = @getTransform()

    div className: 'cursor', style: {height, width, WebkitTransform}

  getTransform: ->
    {pixelRect, scrollTop, scrollLeft, useHardwareAcceleration} = @props
    {top, left} = pixelRect
    top -= scrollTop
    left -= scrollLeft

    if useHardwareAcceleration
      "translate3d(#{left}px, #{top}px, 0px)"
    else
      "translate(#{left}px, #{top}px)"

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'pixelRect', 'scrollTop', 'scrollLeft', 'defaultCharWidth')
