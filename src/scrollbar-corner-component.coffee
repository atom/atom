React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'

module.exports =
ScrollbarCornerComponent = React.createClass
  displayName: 'ScrollbarCornerComponent'

  render: ->
    {visible, measuringScrollbars, width, height} = @props

    if measuringScrollbars
      height = 25
      width = 25

    display = 'none' unless visible

    div className: 'scrollbar-corner', style: {display, width, height},
      div style:
        height: height + 1
        width: width + 1
