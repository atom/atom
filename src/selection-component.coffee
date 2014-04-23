React = require 'react'
{div} = require 'reactionary'

module.exports =
SelectionComponent = React.createClass
  displayName: 'SelectionComponent'

  render: ->
    div className: 'selection',
      for regionRect, i in @props.selection.getRegionRects()
        div className: 'region', key: i, style: regionRect
