React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

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

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'measuringScrollbars', 'visible', 'width', 'height')
