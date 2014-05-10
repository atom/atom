React = require 'react'
{div} = require 'reactionary'

module.exports =
SelectionComponent = React.createClass
  displayName: 'SelectionComponent'

  render: ->
    {scrollTop, scrollLeft} = @props

    div className: 'selection',
      for regionRect, i in @props.selection.getRegionRects()
        {top, left, right, width, height} = regionRect
        top -= scrollTop
        left -= scrollLeft
        right -= scrollLeft
        WebkitTransform = "translate3d(0px, #{top}px, 0px)"
        div className: 'region', key: i, style: {left, right, width, height, WebkitTransform}
