React = require 'react'
{div} = require 'reactionary'

module.exports =
CursorComponent = React.createClass
  displayName: 'CursorComponent'

  render: ->
    {top, left, height, width} = @props.cursor.getPixelRect()
    className = 'cursor'
    className += ' blink-off' if @props.blinkOff

    div className: className, style: {top, left, height, width}
