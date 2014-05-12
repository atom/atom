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

    className = 'cursor'
    className += ' blink-off' if @props.blinkOff

    WebkitTransform = "translate3d(#{left}px, #{top}px, 0px)"

    div className: className, style: {height, width, WebkitTransform}
