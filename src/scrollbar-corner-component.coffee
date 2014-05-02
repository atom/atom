React = require 'react'
{div} = require 'reactionary'

module.exports =
ScrollbarComponent = React.createClass
  render: ->
    {visible, width, height} = @props
    display = 'none' unless visible

    div className: 'scrollbar-corner', style: {display, width, height},
      div style:
        height: height + 1
        width: width + 1
