React = require 'react'
{div} = require 'reactionary'

module.exports =
ScrollbarComponent = React.createClass
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
