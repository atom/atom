React = require 'react'
{div} = require 'reactionary'

module.exports =
SelectionBackgroundsComponent = React.createClass
  displayName: 'SelectionBackgroundsComponent'

  render: ->
    {editor, scrollTop} = @props

    div className: 'selections',
      if @isMounted()
        for selection in editor.getSelections()
          if backgroundRect = selection.getBackgroundRect()
            {top, left, right, height} = backgroundRect
            WebkitTransform = "translate3d(0px, #{top - scrollTop}px, 0px)"
            div className: 'selection', key: selection.id,
              div className: 'region', style: {left, right, height, WebkitTransform}
