React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
ScrollbarCornerComponent = React.createClass
  displayName: 'ScrollbarCornerComponent'

  render: ->
    {presenter, measuringScrollbars} = @props

    visible = presenter.state.horizontalScrollbar.visible and presenter.state.verticalScrollbar.visible
    width = presenter.state.verticalScrollbar.width
    height = presenter.state.horizontalScrollbar.height

    if measuringScrollbars
      height = 25
      width = 25

    display = 'none' unless visible

    div className: 'scrollbar-corner', style: {display, width, height},
      div style:
        height: height + 1
        width: width + 1
