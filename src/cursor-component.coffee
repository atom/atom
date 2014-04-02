{React, div} = require 'reactionary'

module.exports =
CursorComponent = React.createClass
  render: ->
    {top, left, height, width} = @props.cursor.getPixelRect()
    div className: 'cursor', style: {top, left, height, width}
