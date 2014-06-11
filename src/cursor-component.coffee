React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports =
CursorComponent = React.createClass
  displayName: 'CursorComponent'

  render: ->
    {editor, screenRange, scrollTop, scrollLeft, defaultCharWidth} = @props
    {top, left, height, width} = editor.pixelRectForScreenRange(screenRange)
    top -= scrollTop
    left -= scrollLeft
    width = defaultCharWidth if width is 0
    WebkitTransform = "translate3d(#{left}px, #{top}px, 0px)"

    div className: 'cursor', style: {height, width, WebkitTransform}
