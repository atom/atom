{React, div} = require 'reactionary'

module.exports =
CursorComponent = React.createClass
  render: ->
    {cursor, lineHeight, charWidth} = @props
    {row, column} = cursor.getScreenPosition()

    div className: 'cursor', style: {
      height: lineHeight,
      width: charWidth
      top: row * lineHeight
      left: column * charWidth
    }
