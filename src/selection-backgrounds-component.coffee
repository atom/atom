React = require 'react'
{div} = require 'reactionary'

module.exports =
SelectionBackgroundsComponent = React.createClass
  displayName: 'SelectionBackgroundsComponent'

  render: ->
    {editor, lineHeight, scrollTop} = @props

    div className: 'selections',
      if @isMounted()
        for selection in editor.getSelections()
          {start, end} = selection.getScreenRange()
          continue if start.row is end.row

          height = (end.row - start.row) * lineHeight
          top = (start.row * lineHeight) - scrollTop
          left = 0
          right = 0
          WebkitTransform = "translate3d(0px, #{top}px, 0px)"

          div className: 'selection', key: selection.id,
            div className: 'region', style: {left, right, height, WebkitTransform}
