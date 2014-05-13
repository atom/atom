React = require 'react'
{div} = require 'reactionary'

module.exports =
CursorComponent = React.createClass
  displayName: 'CursorComponent'

  render: ->
    {cursor, scrollTop, scrollLeft} = @props
    {top, left, height, width} = cursor.getPixelRect()
    top -= scrollTop
    left -= scrollLeft
    WebkitTransform = "translate3d(#{left}px, #{top}px, 0px)"

    div className: 'cursor', style: {height, width, WebkitTransform}
